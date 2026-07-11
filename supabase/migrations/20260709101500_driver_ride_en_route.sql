-- Driver explicitly starts trip to pickup: status driver_en_route + arrived accepts it.

CREATE OR REPLACE FUNCTION public.fn_driver_ride_en_route(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_status text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT rr.status INTO v_status
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_status = 'driver_en_route' THEN
    RETURN json_build_object(
      'ok', true,
      'status', 'driver_en_route',
      'ride_id', p_ride_request_id,
      'already_en_route', true
    );
  END IF;

  IF v_status NOT IN ('accepted', 'assigned', 'driver_found') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'driver_en_route',
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status IN ('accepted', 'assigned', 'driver_found');

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.en_route',
    v_driver_id,
    jsonb_build_object('status', 'driver_en_route')
  );

  RETURN json_build_object(
    'ok', true,
    'status', 'driver_en_route',
    'ride_id', p_ride_request_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_en_route(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_en_route(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_ride_en_route(uuid) IS
  'Driver started navigation to pickup; rider can show en-route progress.';

-- Allow arrival after explicit en-route start.
CREATE OR REPLACE FUNCTION public.fn_driver_ride_arrived(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_waiting_rate numeric(10, 2);
  v_grace_seconds int := 120;
  v_now timestamptz := timezone('utc', now());
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT COALESCE(d.waiting_time_rate_per_min, rp.waiting_rate, 0)::numeric(10, 2)
  INTO v_waiting_rate
  FROM public.drivers d
  LEFT JOIN public.driver_rate_profiles rp
    ON rp.driver_id = d.id
   AND rp.is_active = true
  WHERE d.id = v_driver_id
  LIMIT 1;

  SELECT COALESCE(NULLIF(rr.waiting_grace_seconds, 0), 120)
  INTO v_grace_seconds
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status IN ('accepted', 'driver_en_route')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'driver_arrived',
    driver_arrived_at = v_now,
    waiting_grace_seconds = v_grace_seconds,
    waiting_started_at = v_now + (v_grace_seconds::text || ' seconds')::interval,
    waiting_rate_per_minute = COALESCE(v_waiting_rate, 0),
    chargeable_wait_seconds = 0,
    waiting_fee_cents = 0,
    waiting_fee_waived = false,
    waiting_fee_waived_at = NULL,
    waiting_fee_waived_by = NULL,
    waiting_fee_waive_reason = NULL,
    updated_at = v_now
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status IN ('accepted', 'driver_en_route');

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.arrived',
    v_driver_id,
    jsonb_build_object(
      'status', 'driver_arrived',
      'waiting_grace_seconds', v_grace_seconds,
      'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
    )
  );
  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'waiting.grace_started',
    v_driver_id,
    jsonb_build_object(
      'grace_seconds', v_grace_seconds,
      'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
    )
  );

  RETURN json_build_object(
    'ok', true,
    'status', 'driver_arrived',
    'ride_id', p_ride_request_id,
    'waiting_grace_seconds', v_grace_seconds,
    'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
  );
END;
$$;
