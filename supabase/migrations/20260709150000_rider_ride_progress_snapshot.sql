-- Live trip progress snapshot for rider: distance remaining, ETA, and progress fraction.
-- Called every few seconds by the rider app during in_progress phase.

CREATE OR REPLACE FUNCTION public.fn_rider_ride_progress_snapshot(
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
  v_driver_id uuid;
  v_driver_lat double precision;
  v_driver_lng double precision;
  v_dest_lat double precision;
  v_dest_lng double precision;
  v_pickup_lat double precision;
  v_pickup_lng double precision;
  v_remaining_m numeric;
  v_total_m numeric;
  v_progress numeric;
  v_eta_min int;
  v_speed_kmh numeric;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT rr.* INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  -- Authorization: rider must own this ride.
  IF NOT (
    EXISTS (
      SELECT 1 FROM public.rider_identities ri
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
        SELECT 1 FROM public.rider_sessions rs
        WHERE rs.user_id = auth.uid()
          AND rs.session_token IS NOT NULL
          AND btrim(rs.session_token) <> ''
          AND v_ride.rider_token = btrim(rs.session_token)
      )
    )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  -- Only meaningful during in_progress.
  IF v_ride.status <> 'in_progress' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'status', v_ride.status,
      'in_progress', false
    );
  END IF;

  v_driver_id := v_ride.driver_id;
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_driver');
  END IF;

  -- Driver's current GPS position.
  SELECT dl.latitude, dl.longitude
  INTO v_driver_lat, v_driver_lng
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
  ORDER BY dl.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_driver_lat IS NULL OR v_driver_lng IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_driver_location');
  END IF;

  -- Destination coordinates from geometry.
  SELECT
    ST_Y(v_ride.destination_coords::geometry),
    ST_X(v_ride.destination_coords::geometry)
  INTO v_dest_lat, v_dest_lng;

  IF v_dest_lat IS NULL OR v_dest_lng IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_destination');
  END IF;

  -- Pickup coordinates (for total trip distance baseline).
  SELECT
    ST_Y(v_ride.pickup_coords::geometry),
    ST_X(v_ride.pickup_coords::geometry)
  INTO v_pickup_lat, v_pickup_lng;

  -- Remaining distance (driver → destination) in meters.
  v_remaining_m := ST_Distance(
    ST_SetSRID(ST_MakePoint(v_driver_lng, v_driver_lat), 4326)::geography,
    ST_SetSRID(ST_MakePoint(v_dest_lng, v_dest_lat), 4326)::geography
  );

  -- Total trip distance (pickup → destination) in meters.
  IF v_pickup_lat IS NOT NULL AND v_pickup_lng IS NOT NULL THEN
    v_total_m := ST_Distance(
      ST_SetSRID(ST_MakePoint(v_pickup_lng, v_pickup_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(v_dest_lng, v_dest_lat), 4326)::geography
    );
  ELSE
    v_total_m := COALESCE(v_ride.estimated_distance_km, 0) * 1000;
  END IF;

  -- Fallback to estimated_distance_km if geometry distance is zero/unavailable.
  IF v_total_m <= 0 AND v_ride.estimated_distance_km IS NOT NULL THEN
    v_total_m := v_ride.estimated_distance_km * 1000;
  END IF;

  -- Progress fraction (0 → 1).
  IF v_total_m > 0 THEN
    v_progress := GREATEST(0.0, LEAST(1.0, 1.0 - (v_remaining_m / v_total_m)));
  ELSE
    v_progress := 0.0;
  END IF;

  -- ETA: conservative city speed profile (28 km/h average).
  v_speed_kmh := 28.0;
  v_eta_min := CEIL((v_remaining_m / 1000.0) / v_speed_kmh * 60.0);
  v_eta_min := GREATEST(1, LEAST(90, v_eta_min));

  RETURN jsonb_build_object(
    'ok', true,
    'status', v_ride.status,
    'in_progress', true,
    'driver_lat', v_driver_lat,
    'driver_lng', v_driver_lng,
    'dest_lat', v_dest_lat,
    'dest_lng', v_dest_lng,
    'remaining_m', round(v_remaining_m)::int,
    'total_m', round(v_total_m)::int,
    'remaining_km', round((v_remaining_m / 1000.0)::numeric, 2),
    'total_km', round((v_total_m / 1000.0)::numeric, 2),
    'progress', round(v_progress::numeric, 4),
    'eta_min', v_eta_min,
    'estimated_distance_km', v_ride.estimated_distance_km,
    'estimated_duration_min', v_ride.estimated_duration_min
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_ride_progress_snapshot(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_ride_progress_snapshot(uuid, text) TO authenticated, anon;

COMMENT ON FUNCTION public.fn_rider_ride_progress_snapshot(uuid, text) IS
  'Live trip progress for rider: distance remaining, ETA, and progress fraction during in_progress phase.';

-- Also fix: grant EXECUTE on fn_rider_driver_location_for_ride to anon for guest riders.
REVOKE ALL ON FUNCTION public.fn_rider_driver_location_for_ride(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_driver_location_for_ride(uuid, text) TO authenticated, anon;
