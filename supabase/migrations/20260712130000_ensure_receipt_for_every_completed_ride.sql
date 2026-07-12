-- Ensure every completed ride has a receipt, regardless of how it was completed
-- and regardless of fare amount (including zero-fare rides)

-- 1. Modify fn_driver_ride_issue_auto_receipt to create receipt even when amount is 0
--    (previously skipped when v_paid <= 0, leaving completed rides without receipts)
CREATE OR REPLACE FUNCTION public.fn_driver_ride_issue_auto_receipt(p_ride_request_id uuid, p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_receipt_id text;
  v_base numeric;
  v_waiting numeric;
  v_paid numeric;
BEGIN
  IF p_ride_request_id IS NULL OR p_driver_id IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.receipts r WHERE r.ride_request_id = p_ride_request_id LIMIT 1) THEN RETURN; END IF;
  SELECT * INTO v_ride FROM public.ride_requests rr WHERE rr.id = p_ride_request_id AND rr.driver_id = p_driver_id AND rr.status = 'completed' LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  v_base := COALESCE(v_ride.final_fare, v_ride.marketplace_offered_fare, v_ride.offered_fare, v_ride.quoted_fare, v_ride.estimated_fare, 0);
  v_waiting := CASE WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0 ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100 END;
  v_paid := v_base + v_waiting;
  -- Create receipt even for zero-amount rides so every completed ride has a receipt
  v_receipt_id := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  INSERT INTO public.receipts (driver_id, receipt_id, amount, distance_km, notes, delivery_method, delivery_status, ride_request_id, country_code, currency, issued_at)
  VALUES (p_driver_id, v_receipt_id, v_paid, COALESCE(v_ride.estimated_distance_km, 0), NULL, 'app', 'delivered', p_ride_request_id, COALESCE(NULLIF(btrim(v_ride.country_code), ''), 'NL'), COALESCE(NULLIF(btrim(v_ride.currency), ''), 'EUR'), timezone('utc', now()));
END;
$function$;

-- 2. Modify fn_rider_receipt_for_ride to return receipt data even for zero-amount rides
CREATE OR REPLACE FUNCTION public.fn_rider_receipt_for_ride(p_ride_request_id uuid, p_rider_token text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    v_ride.estimated_fare,
    0
  );
  v_waiting_fee := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;
  v_expected := v_base_expected + v_waiting_fee;
  v_paid := CASE
    WHEN v_has_receipt THEN v_receipt.amount
    ELSE v_expected
  END;

  -- Return receipt data even for zero-amount rides (every completed ride gets a receipt)
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
$function$;

-- 3. Add trigger as safety net: auto-create receipt when status changes to 'completed'
CREATE OR REPLACE FUNCTION public.trg_auto_receipt_on_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'completed' AND NEW.driver_id IS NOT NULL THEN
    PERFORM public.fn_driver_ride_issue_auto_receipt(NEW.id, NEW.driver_id);
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_auto_receipt_on_complete ON public.ride_requests;
CREATE TRIGGER trg_auto_receipt_on_complete
  AFTER UPDATE OF status ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_auto_receipt_on_complete();

-- Revoke EXECUTE on trigger function so it can't be called via RPC
REVOKE EXECUTE ON FUNCTION public.trg_auto_receipt_on_complete() FROM authenticated, anon;

-- 4. Backfill missing receipts for existing completed rides
INSERT INTO public.receipts (driver_id, receipt_id, amount, distance_km, notes, delivery_method, delivery_status, ride_request_id, country_code, currency, issued_at)
SELECT
  rr.driver_id,
  upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
  COALESCE(rr.final_fare, rr.marketplace_offered_fare, rr.offered_fare, rr.quoted_fare, rr.estimated_fare, 0)
    + CASE WHEN COALESCE(rr.waiting_fee_waived, false) THEN 0 ELSE COALESCE(rr.waiting_fee_cents, 0)::numeric / 100 END,
  COALESCE(rr.estimated_distance_km, 0),
  NULL,
  'app',
  'delivered',
  rr.id,
  COALESCE(NULLIF(btrim(rr.country_code), ''), 'NL'),
  COALESCE(NULLIF(btrim(rr.currency), ''), 'EUR'),
  COALESCE(rr.completed_at, rr.updated_at, timezone('utc', now()))
FROM public.ride_requests rr
WHERE rr.status = 'completed'
  AND rr.driver_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.receipts r WHERE r.ride_request_id = rr.id);
