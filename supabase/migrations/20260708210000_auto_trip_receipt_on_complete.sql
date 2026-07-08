-- Auto-issue trip receipts when a ride completes so riders can open them from history
-- without the driver manually tapping "Send receipt".

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
  v_receipt_id text;
  v_base numeric;
  v_waiting numeric;
  v_paid numeric;
BEGIN
  IF p_ride_request_id IS NULL OR p_driver_id IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.receipts r
    WHERE r.ride_request_id = p_ride_request_id
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = p_driver_id
    AND rr.status = 'completed'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_base := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare,
    v_ride.quoted_fare,
    v_ride.estimated_fare
  );
  v_waiting := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;
  v_paid := COALESCE(v_base, 0) + v_waiting;

  IF v_paid <= 0 THEN
    RETURN;
  END IF;

  v_receipt_id := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

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
    v_receipt_id,
    v_paid,
    COALESCE(v_ride.estimated_distance_km, 0),
    NULL,
    'app',
    'delivered',
    p_ride_request_id,
    COALESCE(NULLIF(btrim(v_ride.country_code), ''), 'NL'),
    COALESCE(NULLIF(btrim(v_ride.currency), ''), 'EUR'),
    timezone('utc', now())
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_issue_auto_receipt(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_issue_auto_receipt(uuid, uuid) TO authenticated;

-- Patch complete ride to auto-issue receipt for the rider.
CREATE OR REPLACE FUNCTION public.fn_driver_ride_complete(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
  v_fee_cents int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status <> 'in_progress' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  v_fee_cents := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)
  END;

  UPDATE public.ride_requests rr
  SET status = 'completed',
      completed_at = timezone('utc', now()),
      waiting_fee_cents = v_fee_cents,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);
  PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_request_id, v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.completed', v_driver_id,
    jsonb_build_object(
      'status', 'completed',
      'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'ride_completed',
    'Trip completed',
    'Thanks for riding with HeyCaby. Rate your driver.',
    jsonb_build_object(
      'type', 'ride_completed',
      'ride_request_id', p_ride_request_id,
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  RETURN json_build_object(
    'ok', true, 'status', 'completed', 'ride_id', p_ride_request_id,
    'waiting_fee_cents', v_fee_cents
  );
END;
$$;

-- Backfill receipts for completed rides that predate auto-issue.
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
SELECT
  rr.driver_id,
  upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
  COALESCE(
    rr.final_fare,
    rr.marketplace_offered_fare,
    rr.offered_fare,
    rr.quoted_fare,
    rr.estimated_fare,
    0
  ) + CASE
    WHEN COALESCE(rr.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(rr.waiting_fee_cents, 0)::numeric / 100
  END,
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
  AND NOT EXISTS (
    SELECT 1
    FROM public.receipts r
    WHERE r.ride_request_id = rr.id
  )
  AND (
    COALESCE(
      rr.final_fare,
      rr.marketplace_offered_fare,
      rr.offered_fare,
      rr.quoted_fare,
      rr.estimated_fare,
      0
    ) + CASE
      WHEN COALESCE(rr.waiting_fee_waived, false) THEN 0
      ELSE COALESCE(rr.waiting_fee_cents, 0)::numeric / 100
    END
  ) > 0;

-- Rider receipt RPC: include route context; synthesize when receipt row missing.
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
  v_base_expected numeric;
  v_waiting_fee numeric;
  v_expected numeric;
  v_paid numeric;
  v_has_receipt boolean := false;
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

REVOKE ALL ON FUNCTION public.fn_rider_receipt_for_ride(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_receipt_for_ride(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_ride_issue_auto_receipt(uuid, uuid) IS
  'Idempotent auto-receipt when a trip completes so riders can view it immediately.';
COMMENT ON FUNCTION public.fn_rider_receipt_for_ride(uuid) IS
  'Rider receipt payload with route context; synthesizes fare when receipt row is missing.';

-- Align manual driver receipt IDs with receipts.receipt_id varchar(12).
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
  v_receipt_id text;
  v_distance numeric;
  v_receipt_row_id uuid;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  IF p_paid_amount IS NULL OR p_paid_amount <= 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_amount');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'completed';

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  v_distance := COALESCE(v_ride.estimated_distance_km, 0);
  v_receipt_id := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

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
    v_driver_id,
    v_receipt_id,
    p_paid_amount,
    v_distance,
    NULLIF(btrim(COALESCE(p_note, '')), ''),
    'app',
    'delivered',
    p_ride_request_id,
    COALESCE(NULLIF(btrim(v_ride.country_code), ''), 'NL'),
    COALESCE(NULLIF(btrim(v_ride.currency), ''), 'EUR'),
    timezone('utc', now())
  )
  RETURNING id INTO v_receipt_row_id;

  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.receipt_created',
    v_driver_id,
    jsonb_build_object(
      'receipt_id', v_receipt_id,
      'paid_amount', p_paid_amount,
      'expected_amount', p_expected_amount,
      'payment_method', p_payment_method
    )
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'receipt_id', v_receipt_id,
    'receipt_row_id', v_receipt_row_id
  );
END;
$$;
