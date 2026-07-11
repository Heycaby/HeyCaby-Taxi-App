-- Notify rider when driver starts navigation to pickup (Head to pickup).

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
  v_ride public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_rider_target text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT rr.* INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  v_status := v_ride.status;

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

  SELECT d.* INTO v_driver FROM public.drivers d WHERE d.id = v_driver_id;
  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  IF v_rider_target IS NOT NULL AND v_rider_target <> '' THEN
    PERFORM public.fn_ride_event_notify(
      'rider',
      v_rider_target,
      'driver_en_route',
      'Driver on the way',
      COALESCE(v_driver.full_name, 'Your driver') || ' is heading to your pickup',
      jsonb_build_object(
        'type', 'driver_en_route',
        'ride_request_id', p_ride_request_id,
        'driver_name', v_driver.full_name
      ),
      'critical'
    );
  END IF;

  RETURN json_build_object(
    'ok', true,
    'status', 'driver_en_route',
    'ride_id', p_ride_request_id
  );
END;
$$;
