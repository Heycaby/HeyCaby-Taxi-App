-- Phase B — Backend Consolidation Program: driver ride lifecycle RPCs (Supabase-first).
-- Replaces Go HTTP paths for arrived / start / complete / cancel / decline / no-show / rate / receipt.
-- Audit + billing hooks: existing ride_requests triggers (ride_audit_log, billing_ledger on complete).

-- ---------------------------------------------------------------------------
-- Internal helpers (not granted to clients)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_lifecycle_resolve_driver()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT d.id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_resolve_driver() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_lifecycle_audit(
  p_ride_id uuid,
  p_event text,
  p_driver_id uuid,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.fn_ride_audit_append(
    p_ride_id,
    p_event,
    p_driver_id,
    COALESCE(p_metadata, '{}'::jsonb),
    'driver',
    'supabase_rpc',
    p_ride_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_audit(uuid, text, uuid, jsonb) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_lifecycle_release_driver(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.drivers
  SET status = 'available'::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = p_driver_id
    AND status = 'on_ride'::public.driver_status;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_release_driver(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_lifecycle_mark_on_ride(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.drivers
  SET status = 'on_ride'::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = p_driver_id
    AND status IN ('available'::public.driver_status, 'on_break'::public.driver_status);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_mark_on_ride(uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Arrived: accepted → driver_arrived
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_arrived(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'driver_arrived',
    driver_arrived_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'accepted';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.arrived',
    v_driver_id,
    jsonb_build_object('status', 'driver_arrived')
  );

  RETURN json_build_object('ok', true, 'status', 'driver_arrived', 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_arrived(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_arrived(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Start: driver_arrived → in_progress
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_start(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'in_progress',
    started_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'driver_arrived';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.started',
    v_driver_id,
    jsonb_build_object('status', 'in_progress')
  );

  RETURN json_build_object('ok', true, 'status', 'in_progress', 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_start(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_start(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Complete: in_progress → completed (+ billing trigger)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_complete(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'completed',
    completed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'in_progress';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);

  RETURN json_build_object('ok', true, 'status', 'completed', 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_complete(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_complete(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Cancel active ride (driver)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_cancel(
  p_ride_request_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'cancelled',
    cancelled_at = timezone('utc', now()),
    cancelled_by = 'driver',
    cancellation_reason = NULLIF(btrim(COALESCE(p_reason, '')), ''),
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status IN ('accepted', 'driver_arrived', 'in_progress');

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);

  RETURN json_build_object('ok', true, 'status', 'cancelled', 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_cancel(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_cancel(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Decline incoming invite (ride stays pending)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_decline_ride_invite(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'no_valid_invite');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'offer.declined',
    v_driver_id,
    jsonb_build_object('driver_id', v_driver_id)
  );

  RETURN json_build_object('ok', true, 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_decline_ride_invite(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_decline_ride_invite(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- No-show at pickup
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_no_show(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'cancelled',
    cancelled_at = timezone('utc', now()),
    cancelled_by = 'driver',
    cancellation_reason = 'no_show',
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'driver_arrived';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.no_show',
    v_driver_id,
    jsonb_build_object('cancelled_by', 'driver')
  );

  RETURN json_build_object('ok', true, 'status', 'cancelled', 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_no_show(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_no_show(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Rate rider (post-trip)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_rate_rider(
  p_ride_request_id uuid,
  p_rating smallint,
  p_comment text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride public.ride_requests%ROWTYPE;
  v_comment text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_rating');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'completed';

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  IF v_ride.rider_token IS NULL OR btrim(v_ride.rider_token) = '' THEN
    RETURN json_build_object('ok', false, 'error', 'missing_rider_token');
  END IF;

  v_comment := NULLIF(btrim(COALESCE(p_comment, '')), '');
  IF v_comment IS NOT NULL AND char_length(v_comment) > 100 THEN
    v_comment := left(v_comment, 100);
  END IF;

  INSERT INTO public.ride_ratings (
    ride_request_id,
    driver_id,
    rider_token,
    driver_rating_of_rider,
    driver_rated_at,
    rider_comment
  )
  VALUES (
    p_ride_request_id,
    v_driver_id,
    v_ride.rider_token,
    p_rating,
    timezone('utc', now()),
    v_comment
  )
  ON CONFLICT (ride_request_id) DO UPDATE
  SET
    driver_rating_of_rider = EXCLUDED.driver_rating_of_rider,
    driver_rated_at = EXCLUDED.driver_rated_at,
    rider_comment = COALESCE(EXCLUDED.rider_comment, public.ride_ratings.rider_comment);

  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.rated',
    v_driver_id,
    jsonb_build_object('rating', p_rating)
  );

  RETURN json_build_object('ok', true, 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_rate_rider(uuid, smallint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_rate_rider(uuid, smallint, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Receipt record (driver → rider)
-- ---------------------------------------------------------------------------

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
  v_receipt_id := 'HC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

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
    'pending',
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

REVOKE ALL ON FUNCTION public.fn_driver_create_receipt(uuid, numeric, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_create_receipt(uuid, numeric, numeric, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_ride_arrived(uuid) IS
  'Phase B: driver marks arrived at pickup (accepted → driver_arrived).';
COMMENT ON FUNCTION public.fn_driver_ride_start(uuid) IS
  'Phase B: passenger onboard (driver_arrived → in_progress).';
COMMENT ON FUNCTION public.fn_driver_ride_complete(uuid) IS
  'Phase B: trip complete (in_progress → completed); billing ledger trigger fires.';
COMMENT ON FUNCTION public.fn_driver_ride_cancel(uuid, text) IS
  'Phase B: driver cancels active ride before completion.';
COMMENT ON FUNCTION public.fn_driver_decline_ride_invite(uuid) IS
  'Phase B: driver declines pending invite; ride stays pending for other drivers.';
COMMENT ON FUNCTION public.fn_driver_ride_no_show(uuid) IS
  'Phase B: rider no-show at pickup (driver_arrived → cancelled).';
COMMENT ON FUNCTION public.fn_driver_rate_rider(uuid, smallint, text) IS
  'Phase B: driver rates rider after completed trip.';
COMMENT ON FUNCTION public.fn_driver_create_receipt(uuid, numeric, numeric, text, text) IS
  'Phase B: record trip receipt for rider.';
