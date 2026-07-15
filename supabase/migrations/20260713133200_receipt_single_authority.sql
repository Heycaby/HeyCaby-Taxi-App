-- Production history 20260713133200. Finance owns receipt state; the completed ride fare snapshot is the
-- only financial input; old clients may still call fn_driver_create_receipt,
-- but that function is now a compatibility wrapper around this path.

CREATE UNIQUE INDEX IF NOT EXISTS receipts_one_per_ride_request_idx
  ON public.receipts (ride_request_id)
  WHERE ride_request_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_issue_auto_receipt(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_base numeric;
  v_waiting numeric;
  v_paid numeric;
BEGIN
  IF p_ride_request_id IS NULL OR p_driver_id IS NULL THEN
    RETURN;
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = p_driver_id
    AND rr.status = 'completed'
  FOR SHARE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_base := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare,
    v_ride.quoted_fare,
    v_ride.estimated_fare,
    0
  );
  v_waiting := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;
  v_paid := v_base + v_waiting;

  INSERT INTO public.receipts (
    driver_id,
    receipt_id,
    amount,
    distance_km,
    notes,
    delivery_method,
    delivery_status,
    ride_request_id,
    country_code,
    currency,
    issued_at
  )
  VALUES (
    p_driver_id,
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
    v_paid,
    COALESCE(v_ride.estimated_distance_km, 0),
    NULL,
    'app',
    'delivered',
    p_ride_request_id,
    COALESCE(NULLIF(btrim(v_ride.country_code), ''), 'NL'),
    COALESCE(NULLIF(btrim(v_ride.currency), ''), 'EUR'),
    timezone('utc', now())
  )
  ON CONFLICT (ride_request_id) WHERE ride_request_id IS NOT NULL
  DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_issue_auto_receipt(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_issue_auto_receipt(uuid, uuid)
  TO service_role;

COMMENT ON FUNCTION public.fn_driver_ride_issue_auto_receipt(uuid, uuid) IS
  'Internal idempotent receipt issuer. Amounts are derived only from the completed ride fare snapshot.';

CREATE OR REPLACE FUNCTION public.fn_driver_create_receipt(
  p_ride_request_id uuid,
  p_paid_amount numeric,
  p_expected_amount numeric DEFAULT NULL,
  p_payment_method text DEFAULT 'cash',
  p_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride public.ride_requests%ROWTYPE;
  v_receipt public.receipts%ROWTYPE;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'completed';

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_request_id, v_driver_id);

  SELECT r.*
  INTO v_receipt
  FROM public.receipts r
  WHERE r.ride_request_id = p_ride_request_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'receipt_not_created');
  END IF;

  -- Keep evidence that an old client supplied a different amount, but never
  -- use caller input as financial truth.
  IF p_paid_amount IS DISTINCT FROM v_receipt.amount
     OR (
       p_expected_amount IS NOT NULL
       AND p_expected_amount IS DISTINCT FROM v_receipt.amount
     ) THEN
    PERFORM public.fn_driver_ride_lifecycle_audit(
      p_ride_request_id,
      'trip.receipt_client_amount_ignored',
      v_driver_id,
      jsonb_build_object(
        'authoritative_amount', v_receipt.amount,
        'client_paid_amount', p_paid_amount,
        'client_expected_amount', p_expected_amount,
        'client_payment_method', p_payment_method,
        'client_note_present', NULLIF(btrim(COALESCE(p_note, '')), '') IS NOT NULL
      )
    );
  END IF;

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'receipt_id', v_receipt.receipt_id,
    'receipt_row_id', v_receipt.id,
    'amount', v_receipt.amount,
    'source', 'completed_ride_snapshot'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_create_receipt(uuid, numeric, numeric, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_create_receipt(uuid, numeric, numeric, text, text)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_driver_create_receipt(uuid, numeric, numeric, text, text) IS
  'Compatibility command for released Driver apps. Caller amounts are ignored; receipt truth comes from the completed ride snapshot.';

NOTIFY pgrst, 'reload schema';
