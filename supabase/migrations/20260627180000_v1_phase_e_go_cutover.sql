-- Phase E — Backend Consolidation: disable Go REST cutover (Supabase-only hot path).
-- Rollback: UPDATE app_config SET value = 'https://api.heycaby.nl' WHERE key = 'driver_rest_api_base_url';

UPDATE public.app_config
SET value = ''
WHERE key = 'driver_rest_api_base_url';

-- Rider receipt view (replaces GET /api/rider/receipt on Go).
CREATE OR REPLACE FUNCTION public.fn_rider_receipt_for_ride(p_ride_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_receipt public.receipts%ROWTYPE;
  v_expected numeric;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND EXISTS (
        SELECT 1
        FROM public.rider_identities ri
        WHERE ri.id = rr.rider_identity_id
          AND ri.user_id = auth.uid()
      )
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  SELECT * INTO v_receipt
  FROM public.receipts r
  WHERE r.ride_request_id = p_ride_request_id
  ORDER BY r.issued_at DESC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_receipt');
  END IF;

  v_expected := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare
  );

  RETURN jsonb_build_object(
    'ok', true,
    'ride_request_id', p_ride_request_id,
    'receipt_id', v_receipt.receipt_id,
    'expected_amount', v_expected,
    'paid_amount', v_receipt.amount,
    'payment_method', COALESCE(NULLIF(btrim(v_ride.payment_method), ''), 'cash'),
    'note', v_receipt.notes,
    'currency', COALESCE(NULLIF(btrim(v_receipt.currency), ''), 'EUR'),
    'issued_at', v_receipt.issued_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_receipt_for_ride(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_receipt_for_ride(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_receipt_for_ride(uuid) IS
  'Phase E: rider receipt payload for completed ride (Supabase-first; no Go).';
