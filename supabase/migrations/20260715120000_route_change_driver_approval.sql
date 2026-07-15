-- Driver must accept mid-ride route edits (stops / destination) before they apply.
-- Rider submits a pending change; driver accepts or rejects via RPC.

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS pending_route_change jsonb;

ALTER TABLE public.ride_requests
  DROP CONSTRAINT IF EXISTS ride_requests_pending_route_change_shape;
ALTER TABLE public.ride_requests
  ADD CONSTRAINT ride_requests_pending_route_change_shape CHECK (
    pending_route_change IS NULL
    OR (
      jsonb_typeof(pending_route_change) = 'object'
      AND nullif(trim(pending_route_change->>'destination_address'), '') IS NOT NULL
      AND jsonb_typeof(coalesce(pending_route_change->'stops', '[]'::jsonb)) = 'array'
      AND jsonb_array_length(coalesce(pending_route_change->'stops', '[]'::jsonb)) <= 3
    )
  );

CREATE OR REPLACE FUNCTION public._route_coords_equal(
  p_lat_a double precision,
  p_lng_a double precision,
  p_lat_b double precision,
  p_lng_b double precision
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT abs(p_lat_a - p_lat_b) <= 0.00005
     AND abs(p_lng_a - p_lng_b) <= 0.00005;
$$;

CREATE OR REPLACE FUNCTION public._route_stops_json_equal(
  p_a jsonb,
  p_b jsonb
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_a jsonb;
  v_b jsonb;
  v_i integer;
  v_len integer;
BEGIN
  v_a := coalesce(p_a, '[]'::jsonb);
  v_b := coalesce(p_b, '[]'::jsonb);
  IF jsonb_typeof(v_a) <> 'array' OR jsonb_typeof(v_b) <> 'array' THEN
    RETURN false;
  END IF;
  v_len := jsonb_array_length(v_a);
  IF v_len <> jsonb_array_length(v_b) THEN
    RETURN false;
  END IF;
  FOR v_i IN 0..(v_len - 1) LOOP
    IF trim(coalesce(v_a->v_i->>'address', '')) <>
       trim(coalesce(v_b->v_i->>'address', '')) THEN
      RETURN false;
    END IF;
    IF NOT public._route_coords_equal(
      (v_a->v_i->>'lat')::double precision,
      (v_a->v_i->>'lng')::double precision,
      (v_b->v_i->>'lat')::double precision,
      (v_b->v_i->>'lng')::double precision
    ) THEN
      RETURN false;
    END IF;
  END LOOP;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public._route_state_equal(
  p_dest_address text,
  p_dest_lat double precision,
  p_dest_lng double precision,
  p_stops jsonb,
  p_ride public.ride_requests
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT trim(coalesce(p_dest_address, '')) = trim(coalesce(p_ride.destination_address, ''))
     AND public._route_coords_equal(
       p_dest_lat, p_dest_lng,
       p_ride.destination_lat, p_ride.destination_lng
     )
     AND public._route_stops_json_equal(p_stops, p_ride.route_stops);
$$;

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
  v_requires_approval boolean;
  v_pending jsonb;
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

  IF public._route_state_equal(
    p_destination_address, p_destination_lat, p_destination_lng, p_stops, v_ride
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_change');
  END IF;

  IF v_ride.pending_route_change IS NOT NULL THEN
    IF trim(coalesce(v_ride.pending_route_change->>'destination_address', '')) =
         trim(p_destination_address)
       AND public._route_coords_equal(
         p_destination_lat, p_destination_lng,
         (v_ride.pending_route_change->>'destination_lat')::double precision,
         (v_ride.pending_route_change->>'destination_lng')::double precision
       )
       AND public._route_stops_json_equal(
         p_stops, coalesce(v_ride.pending_route_change->'stops', '[]'::jsonb)
       ) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'duplicate_request');
    END IF;
    RETURN jsonb_build_object('ok', false, 'error', 'pending_route_change');
  END IF;

  v_requires_approval := v_ride.driver_id IS NOT NULL;

  IF NOT v_requires_approval THEN
    UPDATE public.ride_requests SET
      destination_address = trim(p_destination_address),
      destination_lat = p_destination_lat,
      destination_lng = p_destination_lng,
      destination_coords = ST_SetSRID(ST_MakePoint(p_destination_lng, p_destination_lat), 4326)::geography,
      route_stops = coalesce(p_stops, '[]'::jsonb),
      route_revision = route_revision + 1,
      route_updated_at = now(),
      route_updated_by = 'rider',
      pending_route_change = NULL
    WHERE id = p_ride_request_id
    RETURNING route_revision INTO v_revision;

    INSERT INTO public.ride_audit_log(ride_id, event, actor_id, actor_type, source, metadata)
    VALUES (
      p_ride_request_id, 'ride.route_updated', auth.uid(), 'rider', 'rider_app',
      jsonb_build_object('route_revision', v_revision, 'stop_count', jsonb_array_length(coalesce(p_stops, '[]'::jsonb)))
    );
    RETURN jsonb_build_object('ok', true, 'pending', false, 'route_revision', v_revision);
  END IF;

  v_pending := jsonb_build_object(
    'destination_address', trim(p_destination_address),
    'destination_lat', p_destination_lat,
    'destination_lng', p_destination_lng,
    'stops', coalesce(p_stops, '[]'::jsonb),
    'requested_at', now(),
    'requested_by', 'rider'
  );

  UPDATE public.ride_requests SET
    pending_route_change = v_pending
  WHERE id = p_ride_request_id;

  SELECT user_id INTO v_driver_user_id FROM public.drivers WHERE id = v_ride.driver_id;
  IF v_driver_user_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, user_type, agent, category, title, body, data, priority, channel)
    VALUES (
      v_driver_user_id::text, 'driver', 'driver_agent', 'route_change_request',
      'Route change request',
      'The rider wants to add or change a stop. Can you do it?',
      jsonb_build_object(
        'ride_request_id', p_ride_request_id,
        'pending_route_change', v_pending
      ),
      'high', 'both'
    );
  END IF;

  INSERT INTO public.ride_audit_log(ride_id, event, actor_id, actor_type, source, metadata)
  VALUES (
    p_ride_request_id, 'ride.route_change_requested', auth.uid(), 'rider', 'rider_app',
    jsonb_build_object(
      'stop_count', jsonb_array_length(coalesce(p_stops, '[]'::jsonb)),
      'destination_changed',
        NOT public._route_coords_equal(
          p_destination_lat, p_destination_lng,
          v_ride.destination_lat, v_ride.destination_lng
        )
    )
  );

  RETURN jsonb_build_object('ok', true, 'pending', true, 'pending_route_change', v_pending);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_respond_route_change(
  p_ride_request_id uuid,
  p_accept boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_pending jsonb;
  v_revision integer;
  v_rider_user_id uuid;
  v_stops jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  SELECT rr.* INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.drivers d
    WHERE d.id = v_ride.driver_id AND d.user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  v_pending := v_ride.pending_route_change;
  IF v_pending IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_pending_route_change');
  END IF;

  v_stops := coalesce(v_pending->'stops', '[]'::jsonb);

  IF p_accept THEN
    UPDATE public.ride_requests SET
      destination_address = trim(v_pending->>'destination_address'),
      destination_lat = (v_pending->>'destination_lat')::double precision,
      destination_lng = (v_pending->>'destination_lng')::double precision,
      destination_coords = ST_SetSRID(
        ST_MakePoint(
          (v_pending->>'destination_lng')::double precision,
          (v_pending->>'destination_lat')::double precision
        ),
        4326
      )::geography,
      route_stops = v_stops,
      route_revision = route_revision + 1,
      route_updated_at = now(),
      route_updated_by = 'driver',
      pending_route_change = NULL
    WHERE id = p_ride_request_id
    RETURNING route_revision INTO v_revision;

    SELECT ri.user_id INTO v_rider_user_id
    FROM public.rider_identities ri
    WHERE ri.id = v_ride.rider_identity_id;

    IF v_rider_user_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id, user_type, agent, category, title, body, data, priority, channel)
      VALUES (
        v_rider_user_id::text, 'rider', 'rider_agent', 'route_change_accepted',
        'Stop added', 'Your driver accepted the route change.',
        jsonb_build_object('ride_request_id', p_ride_request_id, 'route_revision', v_revision),
        'normal', 'both'
      );
    END IF;

    INSERT INTO public.ride_audit_log(ride_id, event, actor_id, actor_type, source, metadata)
    VALUES (
      p_ride_request_id, 'ride.route_change_accepted', auth.uid(), 'driver', 'driver_app',
      jsonb_build_object('route_revision', v_revision, 'stop_count', jsonb_array_length(v_stops))
    );

    RETURN jsonb_build_object('ok', true, 'accepted', true, 'route_revision', v_revision);
  END IF;

  UPDATE public.ride_requests SET
    pending_route_change = NULL
  WHERE id = p_ride_request_id;

  SELECT ri.user_id INTO v_rider_user_id
  FROM public.rider_identities ri
  WHERE ri.id = v_ride.rider_identity_id;

  IF v_rider_user_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, user_type, agent, category, title, body, data, priority, channel)
    VALUES (
      v_rider_user_id::text, 'rider', 'rider_agent', 'route_change_rejected',
      'Route change declined', 'Your driver could not take the extra stop.',
      jsonb_build_object('ride_request_id', p_ride_request_id),
      'normal', 'both'
    );
  END IF;

  INSERT INTO public.ride_audit_log(ride_id, event, actor_id, actor_type, source, metadata)
  VALUES (
    p_ride_request_id, 'ride.route_change_rejected', auth.uid(), 'driver', 'driver_app',
    jsonb_build_object('stop_count', jsonb_array_length(v_stops))
  );

  RETURN jsonb_build_object('ok', true, 'accepted', false);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_respond_route_change(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_respond_route_change(uuid, boolean) TO authenticated;

-- Expose pending route change on the Rider snapshot wrapper when installed.
DO $route_snapshot_pending$
BEGIN
  IF to_regprocedure('private.fn_rider_ride_snapshot_base(uuid,text)') IS NOT NULL THEN
    EXECUTE $fn$
CREATE OR REPLACE FUNCTION public.fn_rider_ride_snapshot(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $body$
DECLARE
  v_result jsonb;
  v_booking_mode text;
  v_driver_on_my_way_at timestamptz;
  v_pending jsonb;
BEGIN
  v_result := private.fn_rider_ride_snapshot_base(
    p_ride_request_id,
    p_rider_token
  );

  IF COALESCE((v_result ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  SELECT rr.booking_mode, rr.pending_route_change
  INTO v_booking_mode, v_pending
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  SELECT max(ral.occurred_at)
  INTO v_driver_on_my_way_at
  FROM public.ride_audit_log ral
  WHERE ral.ride_id = p_ride_request_id
    AND (
      ral.event = 'driver.ping_on_my_way'
      OR ral.event LIKE 'driver.ping_on_my_way.%'
      OR ral.event = 'driver.ping_nearby'
      OR ral.event LIKE 'driver.ping_nearby.%'
    );

  RETURN v_result || jsonb_build_object(
    'booking_mode', v_booking_mode,
    'driver_on_my_way', v_driver_on_my_way_at IS NOT NULL,
    'driver_on_my_way_at', v_driver_on_my_way_at,
    'pending_route_change', v_pending
  );
END;
$body$;
$fn$;
  END IF;
END;
$route_snapshot_pending$;

COMMENT ON FUNCTION public.fn_rider_update_active_route(uuid, text, double precision, double precision, jsonb)
IS 'Rider submits mid-ride route edits. When a driver is assigned, changes stay pending until fn_driver_respond_route_change accepts them.';

COMMENT ON FUNCTION public.fn_driver_respond_route_change(uuid, boolean)
IS 'Assigned driver accepts or rejects a pending rider route change.';

NOTIFY pgrst, 'reload schema';
