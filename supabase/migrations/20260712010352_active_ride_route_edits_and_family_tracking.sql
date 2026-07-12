-- Atomic active-ride route editing. Rider and driver read the same revision.
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS route_stops jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS route_revision integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS route_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS route_updated_by text;

ALTER TABLE public.ride_requests
  DROP CONSTRAINT IF EXISTS ride_requests_route_stops_shape;
ALTER TABLE public.ride_requests
  ADD CONSTRAINT ride_requests_route_stops_shape CHECK (
    jsonb_typeof(route_stops) = 'array'
    AND jsonb_array_length(route_stops) <= 3
  );

CREATE OR REPLACE FUNCTION public.fn_rider_update_active_route(
  p_ride_request_id uuid,
  p_destination_address text,
  p_destination_lat double precision,
  p_destination_lng double precision,
  p_stops jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_stop jsonb;
  v_driver_user_id uuid;
  v_revision integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;
  IF nullif(trim(p_destination_address), '') IS NULL
     OR p_destination_lat NOT BETWEEN -90 AND 90
     OR p_destination_lng NOT BETWEEN -180 AND 180 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_destination');
  END IF;
  IF jsonb_typeof(coalesce(p_stops, '[]'::jsonb)) <> 'array'
     OR jsonb_array_length(coalesce(p_stops, '[]'::jsonb)) > 3 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_stops');
  END IF;
  FOR v_stop IN SELECT value FROM jsonb_array_elements(coalesce(p_stops, '[]'::jsonb)) LOOP
    IF nullif(trim(v_stop->>'address'), '') IS NULL
       OR NOT (v_stop ? 'lat') OR NOT (v_stop ? 'lng')
       OR (v_stop->>'lat')::double precision NOT BETWEEN -90 AND 90
       OR (v_stop->>'lng')::double precision NOT BETWEEN -180 AND 180 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'invalid_stop');
    END IF;
  END LOOP;

  SELECT * INTO v_ride FROM public.ride_requests
  WHERE id = p_ride_request_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found'); END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.rider_identities ri
    WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;
  IF v_ride.status::text NOT IN (
    'assigned','accepted','driver_found','driver_en_route','driver_arrived','arrived','in_progress'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_editable', 'status', v_ride.status);
  END IF;

  UPDATE public.ride_requests SET
    destination_address = trim(p_destination_address),
    destination_lat = p_destination_lat,
    destination_lng = p_destination_lng,
    destination_coords = ST_SetSRID(ST_MakePoint(p_destination_lng, p_destination_lat), 4326)::geography,
    route_stops = coalesce(p_stops, '[]'::jsonb),
    route_revision = route_revision + 1,
    route_updated_at = now(),
    route_updated_by = 'rider'
  WHERE id = p_ride_request_id
  RETURNING route_revision INTO v_revision;

  SELECT user_id INTO v_driver_user_id FROM public.drivers WHERE id = v_ride.driver_id;
  IF v_driver_user_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, user_type, agent, category, title, body, data, priority, channel)
    VALUES (
      v_driver_user_id::text, 'driver', 'driver_agent', 'route_changed',
      'Route updated', 'The rider changed the destination or added a stop.',
      jsonb_build_object('ride_request_id', p_ride_request_id, 'route_revision', v_revision),
      'high', 'both'
    );
  END IF;

  INSERT INTO public.ride_audit_log(ride_id, event, actor_id, actor_type, source, metadata)
  VALUES (
    p_ride_request_id, 'ride.route_updated', auth.uid(), 'rider', 'rider_app',
    jsonb_build_object('route_revision', v_revision, 'stop_count', jsonb_array_length(coalesce(p_stops, '[]'::jsonb)))
  );
  RETURN jsonb_build_object('ok', true, 'route_revision', v_revision);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_update_active_route(uuid, text, double precision, double precision, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_update_active_route(uuid, text, double precision, double precision, jsonb) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_update_active_route(uuid, text, double precision, double precision, jsonb)
IS 'Atomically updates an owned active ride destination and up to three ordered stops, then alerts the assigned driver.';
