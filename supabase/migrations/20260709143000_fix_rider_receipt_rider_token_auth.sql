-- Fix fn_rider_receipt_for_ride: allow rider_token authorization fallback.
-- Riders without email login have no auth.uid(), so the existing auth.uid()
-- check always fails and the receipt returns 'not_found'.
-- This patch adds p_rider_token parameter and falls back to matching
-- ride_requests.rider_token when auth.uid() is NULL or doesn't match.

DROP FUNCTION IF EXISTS public.fn_rider_receipt_for_ride(uuid);

CREATE OR REPLACE FUNCTION public.fn_rider_receipt_for_ride(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_receipt public.receipts%ROWTYPE;
  v_base_expected numeric;
  v_waiting_fee numeric;
  v_expected numeric;
  v_paid numeric;
  v_has_receipt boolean := false;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  -- Try auth.uid() match first (email-verified riders).
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.rider_identity_id IS NOT NULL
    AND EXISTS (
        SELECT 1
        FROM public.rider_identities ri
        WHERE ri.id = rr.rider_identity_id
          AND ri.user_id = auth.uid()
      )
  LIMIT 1;

  -- Fallback: match by rider_token (guest riders without email login).
  IF NOT FOUND AND p_rider_token IS NOT NULL AND btrim(p_rider_token) <> '' THEN
    SELECT * INTO v_ride
    FROM public.ride_requests rr
    WHERE rr.id = p_ride_request_id
      AND rr.rider_token = btrim(p_rider_token)
    LIMIT 1;
  END IF;

  -- Final fallback: match by rider_token from session table.
  IF NOT FOUND
     AND auth.uid() IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM public.rider_sessions rs
       WHERE rs.user_id = auth.uid()
         AND rs.session_token IS NOT NULL
         AND btrim(rs.session_token) <> ''
     ) THEN
    SELECT rr.* INTO v_ride
    FROM public.ride_requests rr
    JOIN public.rider_sessions rs
      ON rs.session_token = rr.rider_token
    WHERE rr.id = p_ride_request_id
      AND rs.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF v_ride.status <> 'completed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_completed');
  END IF;

  SELECT * INTO v_receipt
  FROM public.receipts r
  WHERE r.ride_request_id = p_ride_request_id
  ORDER BY r.issued_at DESC NULLS LAST
  LIMIT 1;

  v_has_receipt := FOUND;

  v_base_expected := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare,
    v_ride.quoted_fare,
    v_ride.estimated_fare
  );
  v_waiting_fee := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;
  v_expected := CASE
    WHEN v_base_expected IS NULL THEN NULL
    ELSE v_base_expected + v_waiting_fee
  END;
  v_paid := CASE
    WHEN v_has_receipt THEN v_receipt.amount
    ELSE v_expected
  END;

  IF v_paid IS NULL OR v_paid <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_receipt');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'ride_request_id', p_ride_request_id,
    'receipt_id', CASE WHEN v_has_receipt THEN v_receipt.receipt_id ELSE NULL END,
    'pickup_address', v_ride.pickup_address,
    'destination_address', v_ride.destination_address,
    'completed_at', v_ride.completed_at,
    'base_expected_amount', v_base_expected,
    'waiting_fee_amount', v_waiting_fee,
    'waiting_fee_cents', CASE
      WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
      ELSE COALESCE(v_ride.waiting_fee_cents, 0)
    END,
    'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false),
    'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
    'expected_amount', v_expected,
    'paid_amount', v_paid,
    'payment_method', COALESCE(NULLIF(btrim(v_ride.payment_method), ''), 'cash'),
    'note', CASE WHEN v_has_receipt THEN v_receipt.notes ELSE NULL END,
    'currency', CASE
      WHEN v_has_receipt THEN COALESCE(NULLIF(btrim(v_receipt.currency), ''), 'EUR')
      ELSE COALESCE(NULLIF(btrim(v_ride.currency), ''), 'EUR')
    END,
    'issued_at', CASE
      WHEN v_has_receipt THEN v_receipt.issued_at
      ELSE COALESCE(v_ride.completed_at, v_ride.updated_at)
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_receipt_for_ride(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_receipt_for_ride(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_receipt_for_ride(uuid, text) IS
  'Rider receipt payload with route context; synthesizes fare when receipt row is missing. Authorizes via auth.uid() or rider_token fallback.';
