-- Taxi Terug Phase 4: queued_taxi_terug visibility + dispatch guard.

CREATE OR REPLACE FUNCTION public.fn_driver_has_queued_taxi_terug(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.driver_id = p_driver_id
      AND rr.booking_mode::text = 'terug'
      AND rr.status = 'accepted'
      AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) = true
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_taxi_terug_queue_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_queued public.ride_requests%ROWTYPE;
  v_pickup_min int;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('has_queued', false, 'reason', 'not_a_driver');
  END IF;

  SELECT * INTO v_queued
  FROM public.ride_requests rr
  WHERE rr.driver_id = v_driver_id
    AND rr.booking_mode::text = 'terug'
    AND rr.status = 'accepted'
    AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) = true
  ORDER BY rr.accepted_at ASC NULLS LAST, rr.created_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('has_queued', false);
  END IF;

  v_pickup_min := COALESCE(
    (v_queued.dispatch_state->>'estimated_pickup_minutes')::int, 15
  );

  RETURN jsonb_build_object(
    'has_queued', true,
    'ride_id', v_queued.id,
    'pickup_address', v_queued.pickup_address,
    'destination_address', v_queued.destination_address,
    'destination_label', COALESCE(
      NULLIF(trim(both from v_queued.destination_address), ''),
      'your destination'
    ),
    'estimated_pickup_minutes', v_pickup_min,
    'pickup_available_min', GREATEST(v_pickup_min - 3, 1),
    'pickup_available_max', v_pickup_min + 5,
    'queued_after_ride_id', v_queued.dispatch_state->>'queued_after_ride_id',
    'queued_at', v_queued.dispatch_state->>'queued_at',
    'reserved_for_next_ride', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_taxi_terug_queue_status(
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
  v_driver public.drivers%ROWTYPE;
  v_pickup_min int;
  v_queued boolean;
  v_allowed boolean := false;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ride_not_found');
  END IF;

  v_allowed :=
    EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id
        AND ri.user_id = auth.uid()
    )
    OR (
      p_rider_token IS NOT NULL
      AND btrim(p_rider_token) <> ''
      AND v_ride.rider_token = btrim(p_rider_token)
    )
    OR (
      auth.uid() IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.rider_sessions rs
        WHERE rs.user_id = auth.uid()
          AND rs.session_token IS NOT NULL
          AND btrim(rs.session_token) <> ''
          AND v_ride.rider_token = btrim(rs.session_token)
      )
    );

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'forbidden');
  END IF;

  v_queued := COALESCE((v_ride.dispatch_state->>'queued_taxi_terug')::boolean, false);
  v_pickup_min := COALESCE(
    (v_ride.dispatch_state->>'estimated_pickup_minutes')::int, 0
  );

  IF v_ride.driver_id IS NOT NULL THEN
    SELECT * INTO v_driver FROM public.drivers d WHERE d.id = v_ride.driver_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'ride_request_id', v_ride.id,
    'status', v_ride.status::text,
    'booking_mode', v_ride.booking_mode::text,
    'queued_taxi_terug', v_queued,
    'reserved_for_next_ride', v_queued,
    'estimated_pickup_minutes', NULLIF(v_pickup_min, 0),
    'pickup_available_min',
      CASE WHEN v_pickup_min > 0 THEN GREATEST(v_pickup_min - 3, 1) ELSE NULL END,
    'pickup_available_max',
      CASE WHEN v_pickup_min > 0 THEN v_pickup_min + 5 ELSE NULL END,
    'queued_after_ride_id', v_ride.dispatch_state->>'queued_after_ride_id',
    'queued_at', v_ride.dispatch_state->>'queued_at',
    'activated_at', v_ride.dispatch_state->>'activated_at',
    'driver_name', COALESCE(NULLIF(trim(both from v_driver.full_name), ''), 'Your driver'),
    'driver_vehicle', NULLIF(trim(both from v_driver.vehicle_make_model), ''),
    'driver_rating', v_driver.rating
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_dispatch_driver_eligible(
  p_driver_id uuid,
  p_ride public.ride_requests,
  p_pickup geography,
  p_max_radius_km numeric,
  p_cfg jsonb
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_d public.drivers%ROWTYPE;
  v_dl public.driver_locations%ROWTYPE;
  v_gps_mins int := COALESCE((p_cfg->>'gps_freshness_minutes')::int, 3);
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  SELECT * INTO v_dl
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
  ORDER BY dl.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_dl.driver_id IS NULL
     OR v_dl.updated_at <= now() - make_interval(mins => v_gps_mins)
     OR v_dl.latitude IS NULL
     OR v_dl.longitude IS NULL THEN
    RETURN false;
  END IF;

  IF ST_DWithin(
    ST_SetSRID(ST_MakePoint(v_dl.longitude, v_dl.latitude), 4326)::geography,
    p_pickup,
    p_max_radius_km * 1000.0
  ) = false THEN
    RETURN false;
  END IF;

  IF v_d.status IS DISTINCT FROM 'available' THEN
    RETURN false;
  END IF;

  IF public.fn_driver_has_queued_taxi_terug(p_driver_id) THEN
    RETURN false;
  END IF;

  IF COALESCE((public.fn_driver_can_accept_rides(p_driver_id)->>'allowed')::boolean, false) = false THEN
    RETURN false;
  END IF;

  IF NOT public.fn_payment_compatible(p_driver_id, p_ride.payment_methods) THEN
    RETURN false;
  END IF;

  IF NOT (
    (
      (
        p_ride.vehicle_categories IS NULL
        OR cardinality(p_ride.vehicle_categories) IS NULL
        OR cardinality(p_ride.vehicle_categories) = 0
      )
      AND (
        p_ride.vehicle_category IS NULL
        OR trim(both from p_ride.vehicle_category::text) = ''
        OR lower(trim(both from v_d.vehicle_category::text)) = lower(trim(both from p_ride.vehicle_category::text))
      )
    )
    OR (
      p_ride.vehicle_categories IS NOT NULL
      AND cardinality(p_ride.vehicle_categories) > 0
      AND lower(trim(both from v_d.vehicle_category::text)) = ANY (
        SELECT lower(trim(both from c))
        FROM unnest(p_ride.vehicle_categories) AS c
      )
    )
  ) THEN
    RETURN false;
  END IF;

  IF COALESCE(p_ride.pet_friendly, false)
     AND NOT COALESCE(v_d.accepts_pets, false) THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites x
    WHERE x.ride_request_id = p_ride.id
      AND x.driver_id = p_driver_id
  ) THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites x
    WHERE x.driver_id = p_driver_id
      AND x.status = 'pending'
      AND x.expires_at > now()
      AND x.ride_request_id <> p_ride.id
  ) THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_dispatch(
  p_driver_id uuid,
  p_permissions jsonb,
  p_billing jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_d public.drivers%ROWTYPE;
  v_eligible boolean;
  v_has_queued_terug boolean;
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;

  v_has_queued_terug := public.fn_driver_has_queued_taxi_terug(p_driver_id);

  v_eligible :=
    COALESCE((p_billing->>'allowed')::boolean, false)
    AND v_d.status::text = 'available'
    AND COALESCE(v_d.compliance_status, '') IS DISTINCT FROM 'suspended'
    AND COALESCE((p_permissions->>'can_go_online')::boolean, false)
    AND NOT v_has_queued_terug;

  RETURN jsonb_build_object(
    'eligible', v_eligible,
    'operational_status', v_d.status::text,
    'compliance_status', v_d.compliance_status,
    'queued_taxi_terug', v_has_queued_terug,
    'reserved_for_next_ride', v_has_queued_terug
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_has_queued_taxi_terug(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_taxi_terug_queue_status() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_queue_status(uuid, text) TO authenticated, service_role;
