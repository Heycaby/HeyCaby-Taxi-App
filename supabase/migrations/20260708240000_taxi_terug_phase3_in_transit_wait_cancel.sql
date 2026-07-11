-- Taxi Terug Phase 3: in-transit supply, wait tolerance, queued accept, cancel protection.

UPDATE public.app_config
SET value = (
  COALESCE(NULLIF(btrim(value), '')::jsonb, '{}'::jsonb)
  || jsonb_build_object(
    'handover_buffer_minutes', 5,
    'default_max_wait_minutes', 60,
    'taxi_terug_cancel_hide_threshold', 2,
    'taxi_terug_cancel_hide_hours', 24
  )
)::text
WHERE key = 'terugtaxi_config';

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_config()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_default jsonb := '{
    "enabled": false,
    "gps_freshness_minutes": 5,
    "default_pickup_radius_km": 10,
    "default_discount_pct": 15,
    "min_progress_km": 3,
    "min_progress_ratio": 0.08,
    "invite_window_seconds": 30,
    "max_invites_per_wave": 5,
    "eta_minutes_per_km": 2.2,
    "suggest_home_distance_km": 20,
    "min_match_score": 70,
    "destination_change_cooldown_hours": 4,
    "max_destination_changes_per_day": 3,
    "handover_buffer_minutes": 5,
    "default_max_wait_minutes": 60,
    "taxi_terug_cancel_hide_threshold": 2,
    "taxi_terug_cancel_hide_hours": 24
  }'::jsonb;
  v_raw text;
BEGIN
  SELECT value INTO v_raw FROM public.app_config WHERE key = 'terugtaxi_config';
  IF v_raw IS NULL OR btrim(v_raw) = '' THEN RETURN v_default; END IF;
  BEGIN RETURN v_default || v_raw::jsonb; EXCEPTION WHEN OTHERS THEN RETURN v_default; END;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_has_non_queued_active_ride(p_driver_id uuid)
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
      AND rr.status IN (
        'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
        'in_progress', 'arrived'
      )
      AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) IS FALSE
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_driver_transit_context(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_active record;
  v_loc record;
  v_remaining_km numeric;
  v_remaining_min numeric;
  v_buffer numeric;
  v_eta_per_km numeric;
  v_available_min numeric;
BEGIN
  SELECT
    rr.id,
    rr.status,
    rr.destination_coords
  INTO v_active
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.status IN (
      'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
      'in_progress', 'arrived'
    )
    AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) IS FALSE
  ORDER BY rr.accepted_at DESC NULLS LAST, rr.updated_at DESC
  LIMIT 1;

  IF NOT FOUND OR v_active.destination_coords IS NULL THEN
    RETURN jsonb_build_object('in_transit', false);
  END IF;

  SELECT dl.latitude, dl.longitude
  INTO v_loc
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
  ORDER BY dl.updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'in_transit', true,
      'active_ride_id', v_active.id,
      'remaining_km', null,
      'remaining_minutes', null,
      'estimated_available_minutes', null
    );
  END IF;

  v_remaining_km := ST_Distance(
    ST_SetSRID(ST_MakePoint(v_loc.longitude, v_loc.latitude), 4326)::geography,
    v_active.destination_coords
  ) / 1000.0;
  v_eta_per_km := COALESCE((v_cfg->>'eta_minutes_per_km')::numeric, 2.2);
  v_buffer := COALESCE((v_cfg->>'handover_buffer_minutes')::numeric, 5);
  v_remaining_min := GREATEST(round(v_remaining_km * v_eta_per_km, 0), 1);
  v_available_min := v_remaining_min + v_buffer;

  RETURN jsonb_build_object(
    'in_transit', true,
    'active_ride_id', v_active.id,
    'remaining_km', round(v_remaining_km, 1),
    'remaining_minutes', v_remaining_min,
    'handover_buffer_minutes', v_buffer,
    'estimated_available_minutes', v_available_min,
    'estimated_available_at',
      (timezone('utc', now()) + make_interval(mins => v_available_min::int))::timestamptz
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_recent_cancel_count(p_driver_id uuid)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(*)::int
  FROM public.driver_return_mode_events e
  WHERE e.driver_id = p_driver_id
    AND e.event_type = 'taxi_terug.cancelled_before_pickup'
    AND e.created_at > now() - make_interval(
      hours => COALESCE(
        (public.fn_taxi_terug_config()->>'taxi_terug_cancel_hide_hours')::int,
        24
      )
    );
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_supply_eligible(
  p_driver_id uuid,
  p_ride public.ride_requests,
  p_pickup geography,
  p_max_radius_km numeric
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
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_gps_mins int := COALESCE((v_cfg->>'gps_freshness_minutes')::int, 5);
  v_in_transit boolean;
  v_active_dest geography;
  v_pickup_anchor geography;
  v_pickup_km numeric;
BEGIN
  IF public.fn_taxi_terug_recent_cancel_count(p_driver_id) >= COALESCE(
    (v_cfg->>'taxi_terug_cancel_hide_threshold')::int, 2
  ) THEN
    RETURN false;
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF NOT FOUND OR COALESCE(v_d.return_mode_enabled, false) IS FALSE THEN
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

  v_in_transit := public.fn_driver_has_non_queued_active_ride(p_driver_id);

  IF v_in_transit THEN
    SELECT rr.destination_coords INTO v_active_dest
    FROM public.ride_requests rr
    WHERE rr.driver_id = p_driver_id
      AND rr.status IN (
        'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
        'in_progress', 'arrived'
      )
      AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) IS FALSE
    ORDER BY rr.accepted_at DESC NULLS LAST
    LIMIT 1;
    v_pickup_anchor := COALESCE(
      v_active_dest,
      ST_SetSRID(ST_MakePoint(v_dl.longitude, v_dl.latitude), 4326)::geography
    );
  ELSE
    IF v_d.status IS DISTINCT FROM 'available' THEN
      RETURN false;
    END IF;
    v_pickup_anchor :=
      ST_SetSRID(ST_MakePoint(v_dl.longitude, v_dl.latitude), 4326)::geography;
  END IF;

  v_pickup_km := ST_Distance(v_pickup_anchor, p_pickup) / 1000.0;
  IF v_pickup_km > p_max_radius_km THEN
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
      (p_ride.vehicle_categories IS NULL OR cardinality(p_ride.vehicle_categories) = 0)
      AND (
        p_ride.vehicle_category IS NULL
        OR trim(both from p_ride.vehicle_category::text) = ''
        OR lower(trim(both from v_d.vehicle_category::text)) =
           lower(trim(both from p_ride.vehicle_category::text))
      )
    )
    OR (
      p_ride.vehicle_categories IS NOT NULL
      AND cardinality(p_ride.vehicle_categories) > 0
      AND lower(trim(both from v_d.vehicle_category::text)) = ANY (
        SELECT lower(trim(both from c)) FROM unnest(p_ride.vehicle_categories) AS c
      )
    )
  ) THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_match_score(
  p_pickup_distance_km numeric,
  p_pickup_radius_km numeric,
  p_progress_km numeric,
  p_progress_ratio numeric,
  p_current_to_home_km numeric,
  p_destination_to_home_km numeric,
  p_driver_rating numeric DEFAULT NULL,
  p_wait_minutes numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_direction numeric;
  v_pickup numeric;
  v_destination numeric;
  v_timing numeric;
  v_quality numeric;
  v_total numeric;
  v_why text;
BEGIN
  v_direction := LEAST(GREATEST(COALESCE(p_progress_ratio, 0) / 0.30, 0), 1)
    * LEAST(GREATEST(COALESCE(p_progress_km, 0) / 3.0, 0), 1);

  v_pickup := 1 - LEAST(
    COALESCE(p_pickup_distance_km, 999) / GREATEST(COALESCE(p_pickup_radius_km, 10), 0.1),
    1
  );

  IF COALESCE(p_current_to_home_km, 0) <= 0 THEN
    v_destination := 0;
  ELSE
    v_destination := LEAST(
      GREATEST(1 - (COALESCE(p_destination_to_home_km, 0) / p_current_to_home_km), 0),
      1
    );
  END IF;

  IF p_wait_minutes IS NULL OR p_wait_minutes <= 15 THEN
    v_timing := 1.0;
  ELSE
    v_timing := LEAST(GREATEST(1 - (p_wait_minutes / 90.0), 0), 1);
  END IF;

  v_quality := LEAST(
    GREATEST((COALESCE(p_driver_rating, 4.6) - 3.5) / 1.5, 0),
    1
  );

  v_total := round((
    v_direction * 40 + v_pickup * 20 + v_destination * 20
    + v_timing * 10 + v_quality * 10
  )::numeric, 1);

  v_why := 'Closer to home after this trip';
  IF COALESCE(p_wait_minutes, 0) > 15 THEN
    v_why := v_why || ' · finishing current ride first';
  ELSIF v_pickup >= 0.6 THEN
    v_why := v_why || ' · pickup nearby';
  END IF;

  RETURN jsonb_build_object(
    'match_score', v_total,
    'direction_score', round(v_direction * 100, 1),
    'pickup_score', round(v_pickup * 100, 1),
    'destination_score', round(v_destination * 100, 1),
    'timing_score', round(v_timing * 100, 1),
    'driver_quality_score', round(v_quality * 100, 1),
    'pickup_detour_km', round(COALESCE(p_pickup_distance_km, 0), 2),
    'destination_fit', round(v_destination * 100, 1),
    'timing_fit', round(v_timing * 100, 1),
    'why_match', v_why
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_terugtaxi_qualify(
  p_driver_id uuid,
  p_ride_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_ride public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_loc record;
  v_transit jsonb;
  v_current geography;
  v_home geography;
  v_pickup_anchor geography;
  v_pickup_distance_km numeric;
  v_current_to_home_km numeric;
  v_destination_to_home_km numeric;
  v_progress_km numeric;
  v_progress_ratio numeric;
  v_pickup_radius_km numeric;
  v_min_progress_km numeric;
  v_min_progress_ratio numeric;
  v_min_match_score numeric;
  v_allowed boolean := false;
  v_reason text := 'unknown';
  v_score jsonb;
  v_match_score numeric;
  v_in_transit boolean := false;
  v_wait_minutes numeric;
  v_eta_per_km numeric;
  v_post_drop_pickup_min numeric;
BEGIN
  IF COALESCE((v_cfg->>'enabled')::boolean, false) IS FALSE THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'disabled');
  END IF;

  IF public.fn_taxi_terug_recent_cancel_count(p_driver_id) >= COALESCE(
    (v_cfg->>'taxi_terug_cancel_hide_threshold')::int, 2
  ) THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'taxi_terug_cancel_penalty');
  END IF;

  SELECT * INTO v_ride FROM public.ride_requests WHERE id = p_ride_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'ride_not_found');
  END IF;
  IF v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'not_taxi_terug');
  END IF;
  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'ride_not_pending');
  END IF;
  IF v_ride.pickup_coords IS NULL OR v_ride.destination_coords IS NULL THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'missing_route');
  END IF;

  SELECT * INTO v_driver FROM public.drivers WHERE id = p_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'driver_not_found');
  END IF;
  IF COALESCE(v_driver.return_mode_enabled, false) IS FALSE THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'return_mode_off');
  END IF;
  IF v_driver.return_mode_destination_lat IS NULL
     OR v_driver.return_mode_destination_lng IS NULL THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'missing_destination');
  END IF;

  SELECT dl.* INTO v_loc
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
    AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
    AND dl.updated_at > now() - make_interval(
      mins => COALESCE((v_cfg->>'gps_freshness_minutes')::int, 5)
    )
  ORDER BY dl.updated_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'stale_location');
  END IF;

  v_pickup_radius_km := COALESCE(
    NULLIF(v_driver.pickup_distance_max_km, 0),
    (v_cfg->>'default_pickup_radius_km')::numeric, 10
  );

  IF public.fn_taxi_terug_supply_eligible(
    p_driver_id, v_ride, v_ride.pickup_coords, v_pickup_radius_km
  ) IS FALSE THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'not_supply_eligible');
  END IF;

  v_transit := public.fn_taxi_terug_driver_transit_context(p_driver_id);
  v_in_transit := COALESCE((v_transit->>'in_transit')::boolean, false);
  v_eta_per_km := COALESCE((v_cfg->>'eta_minutes_per_km')::numeric, 2.2);

  v_current := ST_SetSRID(ST_MakePoint(v_loc.longitude, v_loc.latitude), 4326)::geography;
  v_home := ST_SetSRID(
    ST_MakePoint(v_driver.return_mode_destination_lng, v_driver.return_mode_destination_lat),
    4326
  )::geography;

  IF v_in_transit THEN
    SELECT rr.destination_coords INTO v_pickup_anchor
    FROM public.ride_requests rr
    WHERE rr.driver_id = p_driver_id
      AND rr.status IN (
        'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
        'in_progress', 'arrived'
      )
      AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) IS FALSE
    ORDER BY rr.accepted_at DESC NULLS LAST LIMIT 1;
    v_pickup_anchor := COALESCE(v_pickup_anchor, v_current);
    v_post_drop_pickup_min := ST_Distance(v_pickup_anchor, v_ride.pickup_coords) / 1000.0 * v_eta_per_km;
    v_wait_minutes := COALESCE((v_transit->>'estimated_available_minutes')::numeric, 0)
      + GREATEST(v_post_drop_pickup_min, 1);
  ELSE
    v_pickup_anchor := v_current;
    v_wait_minutes := ST_Distance(v_current, v_ride.pickup_coords) / 1000.0 * v_eta_per_km;
  END IF;

  v_pickup_distance_km := ST_Distance(v_pickup_anchor, v_ride.pickup_coords) / 1000.0;
  v_current_to_home_km := ST_Distance(v_current, v_home) / 1000.0;
  v_destination_to_home_km := ST_Distance(v_ride.destination_coords, v_home) / 1000.0;
  v_progress_km := v_current_to_home_km - v_destination_to_home_km;
  v_progress_ratio := CASE
    WHEN v_current_to_home_km <= 0 THEN 0 ELSE v_progress_km / v_current_to_home_km END;
  v_min_progress_km := COALESCE((v_cfg->>'min_progress_km')::numeric, 3);
  v_min_progress_ratio := COALESCE((v_cfg->>'min_progress_ratio')::numeric, 0.08);
  v_min_match_score := COALESCE((v_cfg->>'min_match_score')::numeric, 70);

  v_score := public.fn_taxi_terug_match_score(
    v_pickup_distance_km, v_pickup_radius_km, v_progress_km, v_progress_ratio,
    v_current_to_home_km, v_destination_to_home_km, v_driver.rating, v_wait_minutes
  );
  v_match_score := (v_score->>'match_score')::numeric;

  IF v_pickup_distance_km > v_pickup_radius_km THEN
    v_reason := 'outside_pickup_radius';
  ELSIF v_progress_km < v_min_progress_km THEN
    v_reason := 'not_enough_progress_home';
  ELSIF v_progress_ratio < v_min_progress_ratio THEN
    v_reason := 'wrong_direction';
  ELSIF v_match_score < v_min_match_score THEN
    v_reason := 'low_match_score';
  ELSE
    v_allowed := true;
    v_reason := 'qualified';
  END IF;

  RETURN jsonb_build_object(
    'qualified', v_allowed, 'reason', v_reason,
    'driver_id', p_driver_id, 'ride_request_id', p_ride_request_id,
    'destination_label', v_driver.return_mode_destination_label,
    'pickup_distance_km', round(v_pickup_distance_km, 2),
    'pickup_radius_km', round(v_pickup_radius_km, 2),
    'current_to_home_km', round(v_current_to_home_km, 2),
    'destination_to_home_km', round(v_destination_to_home_km, 2),
    'progress_toward_home_km', round(v_progress_km, 2),
    'progress_ratio', round(v_progress_ratio, 4),
    'return_discount_pct', COALESCE(v_driver.active_return_discount_pct, 0),
    'match_score', v_match_score, 'why_match', v_score->>'why_match',
    'pickup_detour_km', v_score->>'pickup_detour_km',
    'destination_fit', v_score->>'destination_fit',
    'timing_fit', v_score->>'timing_fit',
    'direction_score', v_score->>'direction_score',
    'pickup_score', v_score->>'pickup_score',
    'destination_score', v_score->>'destination_score',
    'in_transit', v_in_transit,
    'estimated_pickup_minutes', round(COALESCE(v_wait_minutes, 0), 0),
    'estimated_available_minutes', v_transit->>'estimated_available_minutes'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_taxi_terug_candidates(
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_destination_lat double precision,
  p_destination_lng double precision,
  p_limit int DEFAULT 10,
  p_max_wait_minutes int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_pickup geography;
  v_destination geography;
  v_trip_km numeric;
  v_default_radius numeric;
  v_min_progress_km numeric;
  v_min_progress_ratio numeric;
  v_min_match_score numeric;
  v_eta_per_km numeric;
  v_max_wait int;
  v_candidates jsonb;
BEGIN
  IF COALESCE((v_cfg->>'enabled')::boolean, false) IS FALSE THEN
    RETURN jsonb_build_object('enabled', false, 'candidates', '[]'::jsonb);
  END IF;
  IF p_pickup_lat IS NULL OR p_pickup_lng IS NULL
     OR p_destination_lat IS NULL OR p_destination_lng IS NULL THEN
    RETURN jsonb_build_object('enabled', true, 'candidates', '[]'::jsonb, 'reason', 'missing_route');
  END IF;

  v_pickup := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  v_destination := ST_SetSRID(ST_MakePoint(p_destination_lng, p_destination_lat), 4326)::geography;
  v_trip_km := ST_Distance(v_pickup, v_destination) / 1000.0;
  v_default_radius := COALESCE((v_cfg->>'default_pickup_radius_km')::numeric, 10);
  v_min_progress_km := COALESCE((v_cfg->>'min_progress_km')::numeric, 3);
  v_min_progress_ratio := COALESCE((v_cfg->>'min_progress_ratio')::numeric, 0.08);
  v_min_match_score := COALESCE((v_cfg->>'min_match_score')::numeric, 70);
  v_eta_per_km := COALESCE((v_cfg->>'eta_minutes_per_km')::numeric, 2.2);
  v_max_wait := COALESCE(
    p_max_wait_minutes,
    (v_cfg->>'default_max_wait_minutes')::int,
    60
  );

  WITH base AS (
    SELECT
      d.id AS driver_id,
      split_part(COALESCE(NULLIF(trim(d.full_name), ''), 'Chauffeur'), ' ', 1) AS driver_first_name,
      NULLIF(trim(concat_ws(' ', d.vehicle_make, d.vehicle_model)), '') AS vehicle_label,
      COALESCE(d.rating, 4.6) AS driver_rating,
      COALESCE(d.active_return_discount_pct, 0) AS return_discount_pct,
      d.return_mode_destination_label AS heading_to,
      ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography AS current_pos,
      ST_SetSRID(
        ST_MakePoint(d.return_mode_destination_lng, d.return_mode_destination_lat),
        4326
      )::geography AS home_pos,
      COALESCE(NULLIF(d.pickup_distance_max_km, 0), v_default_radius) AS pickup_radius_km,
      public.fn_taxi_terug_driver_transit_context(d.id) AS transit,
      rp.base_fare, rp.per_km_rate, rp.per_min_rate, rp.minimum_fare
    FROM public.drivers d
    JOIN public.driver_locations dl ON dl.driver_id = d.id
    LEFT JOIN LATERAL (
      SELECT p.base_fare, p.per_km_rate, p.per_min_rate, p.minimum_fare
      FROM public.driver_rate_profiles p
      WHERE p.driver_id = d.id AND p.is_active IS TRUE
      ORDER BY p.updated_at DESC NULLS LAST LIMIT 1
    ) rp ON true
    WHERE COALESCE(d.return_mode_enabled, false) IS TRUE
      AND d.return_mode_destination_lat IS NOT NULL
      AND d.return_mode_destination_lng IS NOT NULL
      AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - make_interval(
        mins => COALESCE((v_cfg->>'gps_freshness_minutes')::int, 5)
      )
      AND public.fn_taxi_terug_recent_cancel_count(d.id) <
        COALESCE((v_cfg->>'taxi_terug_cancel_hide_threshold')::int, 2)
      AND (
        d.status = 'available'
        OR public.fn_driver_has_non_queued_active_ride(d.id)
      )
  ),
  scored AS (
    SELECT
      b.*,
      COALESCE((b.transit->>'in_transit')::boolean, false) AS in_transit,
      CASE
        WHEN COALESCE((b.transit->>'in_transit')::boolean, false) THEN (
          SELECT ST_Distance(rr.destination_coords, v_pickup) / 1000.0
          FROM public.ride_requests rr
          WHERE rr.driver_id = b.driver_id
            AND rr.status IN (
              'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
              'in_progress', 'arrived'
            )
            AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) IS FALSE
          ORDER BY rr.accepted_at DESC NULLS LAST LIMIT 1
        )
        ELSE ST_Distance(b.current_pos, v_pickup) / 1000.0
      END AS pickup_distance_km,
      ST_Distance(b.current_pos, b.home_pos) / 1000.0 AS current_to_home_km,
      ST_Distance(v_destination, b.home_pos) / 1000.0 AS destination_to_home_km
    FROM base b
  ),
  metrics AS (
    SELECT
      s.*,
      s.current_to_home_km - s.destination_to_home_km AS progress_km,
      CASE WHEN s.current_to_home_km <= 0 THEN 0
        ELSE (s.current_to_home_km - s.destination_to_home_km) / s.current_to_home_km
      END AS progress_ratio,
      CASE
        WHEN s.in_transit THEN
          COALESCE((s.transit->>'estimated_available_minutes')::numeric, 0)
          + GREATEST(round(s.pickup_distance_km * v_eta_per_km, 0), 1)
        ELSE GREATEST(round(s.pickup_distance_km * v_eta_per_km, 0), 1)
      END AS pickup_eta_minutes,
      GREATEST(
        COALESCE(s.base_fare, 0) + COALESCE(s.per_km_rate, 0) * v_trip_km
        + COALESCE(s.per_min_rate, 0) * GREATEST(v_trip_km * v_eta_per_km, 5),
        COALESCE(s.minimum_fare, 0)
      ) AS fare_base
    FROM scored s
    WHERE s.pickup_distance_km <= s.pickup_radius_km
  ),
  qualified AS (
    SELECT
      m.*,
      public.fn_taxi_terug_match_score(
        m.pickup_distance_km, m.pickup_radius_km, m.progress_km, m.progress_ratio,
        m.current_to_home_km, m.destination_to_home_km, m.driver_rating,
        m.pickup_eta_minutes
      ) AS score_payload
    FROM metrics m
    WHERE m.progress_km >= v_min_progress_km
      AND m.progress_ratio >= v_min_progress_ratio
      AND m.pickup_eta_minutes <= v_max_wait
  ),
  ranked AS (
    SELECT
      q.driver_id, q.driver_first_name, q.vehicle_label, q.driver_rating,
      q.heading_to, q.pickup_eta_minutes, q.in_transit,
      (q.transit->>'estimated_available_minutes')::int AS available_after_minutes,
      (q.score_payload->>'match_score')::numeric AS match_score,
      q.score_payload->>'why_match' AS why_match,
      round(q.fare_base * (1 - LEAST(q.return_discount_pct, 40) / 100.0), 2) AS estimated_fare_min,
      round(q.fare_base, 2) AS estimated_fare_max
    FROM qualified q
    WHERE (q.score_payload->>'match_score')::numeric >= v_min_match_score
    ORDER BY match_score DESC, pickup_eta_minutes ASC
    LIMIT GREATEST(LEAST(COALESCE(p_limit, 10), 20), 1)
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'driver_id', r.driver_id,
      'driver_name', r.driver_first_name,
      'vehicle', r.vehicle_label,
      'heading_to', r.heading_to,
      'pickup_eta_minutes', r.pickup_eta_minutes,
      'estimated_fare_min', r.estimated_fare_min,
      'estimated_fare_max', r.estimated_fare_max,
      'match_score', r.match_score,
      'why_match', r.why_match,
      'driver_rating', round(r.driver_rating::numeric, 1),
      'in_transit', r.in_transit,
      'available_after_minutes', r.available_after_minutes,
      'pickup_available_min', GREATEST(r.pickup_eta_minutes - 3, 1),
      'pickup_available_max', r.pickup_eta_minutes + 5
    )
  ), '[]'::jsonb)
  INTO v_candidates FROM ranked r;

  RETURN jsonb_build_object(
    'enabled', true,
    'trip_distance_km', round(v_trip_km, 1),
    'max_wait_minutes', v_max_wait,
    'candidate_count', COALESCE(jsonb_array_length(v_candidates), 0),
    'candidates', v_candidates
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_activate_queued_ride(
  p_driver_id uuid,
  p_completed_ride_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_queued public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_rider_target text;
  v_pickup_min int;
BEGIN
  SELECT * INTO v_queued
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.booking_mode::text = 'terug'
    AND rr.status = 'accepted'
    AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) = true
    AND (rr.dispatch_state->>'queued_after_ride_id')::uuid = p_completed_ride_id
  ORDER BY rr.accepted_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_queued_ride');
  END IF;

  v_pickup_min := COALESCE(
    (v_queued.dispatch_state->>'estimated_pickup_minutes')::int, 15
  );

  UPDATE public.ride_requests rr
  SET dispatch_state = COALESCE(rr.dispatch_state, '{}'::jsonb) || jsonb_build_object(
        'queued_taxi_terug', false,
        'activated_at', timezone('utc', now())
      ),
      updated_at = timezone('utc', now())
  WHERE rr.id = v_queued.id;

  UPDATE public.drivers d
  SET status = 'busy', updated_at = timezone('utc', now())
  WHERE d.id = p_driver_id;

  SELECT * INTO v_driver FROM public.drivers d WHERE d.id = p_driver_id;

  v_rider_target := COALESCE(v_queued.rider_identity_id::text, v_queued.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'driver_found',
    'Taxi Terug driver ready',
    format('Pickup available in about %s min', v_pickup_min),
    jsonb_build_object(
      'type', 'taxi_terug_activated',
      'ride_request_id', v_queued.id,
      'pickup_eta_minutes', v_pickup_min,
      'queued_taxi_terug', false
    ),
    'critical'
  );

  IF v_driver.user_id IS NOT NULL THEN
    PERFORM public.fn_ride_event_notify(
      'driver', v_driver.user_id::text, 'taxi_terug_next_ride',
      'Taxi Terug booked',
      'Next rider is ready — navigate to pickup when you are set.',
      jsonb_build_object(
        'type', 'taxi_terug_next_ride',
        'ride_request_id', v_queued.id
      ),
      'high'
    );
  END IF;

  PERFORM public.fn_ride_audit_append(
    v_queued.id, 'taxi_terug.activated', p_driver_id,
    jsonb_build_object(
      'completed_ride_id', p_completed_ride_id,
      'pickup_eta_minutes', v_pickup_min
    ),
    'system', 'rpc', v_queued.id
  );

  RETURN jsonb_build_object('ok', true, 'ride_id', v_queued.id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_has_non_queued_active_ride(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_driver_transit_context(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_supply_eligible(uuid, public.ride_requests, geography, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_activate_queued_ride(uuid, uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_queue_accepted_invite(
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
  v_active_ride_id uuid;
  v_transit jsonb;
  v_pickup_min int;
  v_rider_target text;
BEGIN
  SELECT * INTO v_ride FROM public.ride_requests WHERE id = p_ride_request_id;
  IF NOT FOUND OR v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN;
  END IF;

  SELECT rr.id INTO v_active_ride_id
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.id <> p_ride_request_id
    AND rr.status IN (
      'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
      'in_progress', 'arrived'
    )
    AND COALESCE((rr.dispatch_state->>'queued_taxi_terug')::boolean, false) IS FALSE
  ORDER BY rr.accepted_at DESC NULLS LAST
  LIMIT 1;

  IF v_active_ride_id IS NULL THEN
    RETURN;
  END IF;

  v_transit := public.fn_taxi_terug_driver_transit_context(p_driver_id);
  v_pickup_min := GREATEST(
    COALESCE((v_transit->>'estimated_available_minutes')::int, 10) + 5,
    10
  );

  UPDATE public.ride_requests rr
  SET dispatch_state = COALESCE(rr.dispatch_state, '{}'::jsonb) || jsonb_build_object(
        'queued_taxi_terug', true,
        'queued_after_ride_id', v_active_ride_id,
        'estimated_pickup_minutes', v_pickup_min,
        'queued_at', timezone('utc', now())
      ),
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'taxi_terug_queued',
    'Taxi Terug confirmed',
    format('Pickup available in about %s–%s min', GREATEST(v_pickup_min - 3, 1), v_pickup_min + 5),
    jsonb_build_object(
      'type', 'taxi_terug_queued',
      'ride_request_id', p_ride_request_id,
      'pickup_eta_minutes', v_pickup_min,
      'queued_taxi_terug', true
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'taxi_terug.queued', p_driver_id,
    jsonb_build_object(
      'queued_after_ride_id', v_active_ride_id,
      'estimated_pickup_minutes', v_pickup_min
    ),
    'driver', 'rpc', p_ride_request_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_handle_driver_cancel(
  p_ride_request_id uuid,
  p_driver_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_hide_threshold int;
BEGIN
  SELECT * INTO v_ride FROM public.ride_requests WHERE id = p_ride_request_id;
  IF NOT FOUND OR v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN;
  END IF;

  INSERT INTO public.driver_return_mode_events (driver_id, event_type, payload)
  VALUES (
    p_driver_id,
    'taxi_terug.cancelled_before_pickup',
    jsonb_build_object(
      'ride_request_id', p_ride_request_id,
      'reason', p_reason,
      'previous_status', v_ride.status,
      'queued_taxi_terug',
      COALESCE((v_ride.dispatch_state->>'queued_taxi_terug')::boolean, false)
    )
  );

  v_hide_threshold := COALESCE((v_cfg->>'taxi_terug_cancel_hide_threshold')::int, 2);
  IF public.fn_taxi_terug_recent_cancel_count(p_driver_id) >= v_hide_threshold THEN
    INSERT INTO public.driver_return_mode_events (driver_id, event_type, payload)
    VALUES (
      p_driver_id,
      'taxi_terug.supply_hidden',
      jsonb_build_object(
        'reason', 'cancel_threshold',
        'cancel_count', public.fn_taxi_terug_recent_cancel_count(p_driver_id),
        'hide_hours', COALESCE((v_cfg->>'taxi_terug_cancel_hide_hours')::int, 24)
      )
    );
  END IF;

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'taxi_terug_driver_cancelled',
    'Taxi Terug cancelled',
    'Your driver cancelled. You can book another Taxi Terug right away.',
    jsonb_build_object(
      'type', 'taxi_terug_driver_cancelled',
      'ride_request_id', p_ride_request_id,
      'cancelled_by', 'driver'
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'taxi_terug.driver_cancelled', p_driver_id,
    jsonb_build_object('reason', p_reason),
    'driver', 'rpc', p_ride_request_id
  );
END;
$$;

-- Hook: activate queued Taxi Terug after current ride completes.
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
  v_queued jsonb;
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
  v_queued := public.fn_taxi_terug_activate_queued_ride(v_driver_id, p_ride_request_id);
  PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_request_id, v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.completed', v_driver_id,
    jsonb_build_object(
      'status', 'completed',
      'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false),
      'queued_taxi_terug_activated', COALESCE((v_queued->>'ok')::boolean, false)
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
    'waiting_fee_cents', v_fee_cents,
    'queued_taxi_terug_activated', COALESCE((v_queued->>'ok')::boolean, false)
  );
END;
$$;

-- Hook: Taxi Terug cancel protection + rider notify.
CREATE OR REPLACE FUNCTION public.fn_driver_ride_cancel(
  p_ride_request_id uuid,
  p_reason text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
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
     OR v_ride.status NOT IN ('accepted', 'driver_arrived', 'in_progress') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  IF v_ride.booking_mode::text = 'terug' THEN
    PERFORM public.fn_taxi_terug_handle_driver_cancel(
      p_ride_request_id, v_driver_id, p_reason
    );
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'cancelled',
      cancelled_at = timezone('utc', now()),
      cancelled_by = 'driver',
      cancellation_reason = NULLIF(btrim(COALESCE(p_reason, '')), ''),
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.cancelled', v_driver_id,
    jsonb_build_object(
      'actor', 'driver',
      'reason', p_reason,
      'previous_status', v_ride.status
    ),
    'driver', 'rpc', p_ride_request_id
  );

  IF v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
    PERFORM public.fn_ride_event_notify(
      'rider', v_rider_target, 'ride_cancelled',
      'Ride cancelled',
      'Your driver cancelled this ride. You can book again right away.',
      jsonb_build_object(
        'type', 'ride_cancelled',
        'ride_request_id', p_ride_request_id,
        'cancelled_by', 'driver'
      ),
      'critical'
    );
  END IF;

  RETURN json_build_object('ok', true, 'status', 'cancelled', 'ride_id', p_ride_request_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_queue_accepted_invite(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_handle_driver_cancel(uuid, uuid, text) TO authenticated, service_role;
CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_d public.drivers%ROWTYPE;
  v_conversation_id uuid;
  v_rider_target text;
  v_accept_grace int := 30;
  v_invite_diag jsonb;
  v_gps_updated_at timestamptz;
  v_reject jsonb;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'not_a_driver',
      'reason', 'not_a_driver',
      'message', 'Driver profile not found for this account.'
    );
    RETURN v_reject::json;
  END IF;

  IF to_regprocedure('public.fn_dispatch_config()') IS NOT NULL THEN
    v_accept_grace := COALESCE(
      (public.fn_dispatch_config()->>'min_driver_accept_window_seconds')::int,
      30
    );
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'ride_not_found',
      'reason', 'ride_not_found',
      'message', 'This ride no longer exists.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.status = 'accepted' AND v_ride.driver_id = v_driver_id THEN
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    WHERE c.ride_request_id = p_ride_request_id;
    RETURN json_build_object(
      'ok', true, 'already_accepted', true,
      'ride_id', p_ride_request_id,
      'conversation_id', v_conversation_id
    );
  END IF;

  IF v_ride.status <> 'pending' THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'race_lost',
      'reason', 'ride_not_pending',
      'message', 'Another driver already accepted this ride.',
      'details', jsonb_build_object(
        'ride_status', v_ride.status,
        'ride_driver_id', v_ride.driver_id
      )
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) = false THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'billing_locked',
      'reason', 'billing_locked',
      'message', COALESCE(v_billing->>'reason', 'Outstanding platform fees exceed market limit.'),
      'details', v_billing
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  PERFORM public.fn_ensure_driver_ride_invite(p_ride_request_id, v_driver_id);
  v_invite_diag := public.fn_accept_invite_diagnostic(
    p_ride_request_id, v_driver_id, v_accept_grace
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status IN ('pending', 'wave_expired', 'expired')
      AND i.expires_at > now() - make_interval(secs => v_accept_grace)
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'no_valid_invite',
      'reason', CASE
        WHEN COALESCE((v_invite_diag->>'invite_exists')::boolean, false) = false
          THEN 'invite_missing'
        WHEN COALESCE((v_invite_diag->>'invite_expired')::boolean, false) = true
          THEN 'invite_expired'
        ELSE 'invite_not_pending'
      END,
      'message', CASE
        WHEN COALESCE((v_invite_diag->>'invite_exists')::boolean, false) = false
          THEN 'No invite found for this driver on this ride.'
        WHEN COALESCE((v_invite_diag->>'invite_expired')::boolean, false) = true
          THEN 'Your invite window has passed.'
        ELSE 'Invite is not in a valid state for accept.'
      END,
      'details', v_invite_diag || jsonb_build_object(
        'accept_grace_seconds', v_accept_grace,
        'ride_status', v_ride.status,
        'ride_expires_at', v_ride.expires_at
      )
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id AND rp.is_active = true
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'missing_tariff', 'reason', 'missing_tariff',
      'message', 'Set your tariff before accepting rides.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  SELECT dl.updated_at INTO v_gps_updated_at
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
    AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
    AND dl.updated_at > now() - interval '5 minutes'
  LIMIT 1;

  IF v_gps_updated_at IS NULL THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'stale_location', 'reason', 'gps_stale',
      'message', 'Your GPS location is stale. Enable location and try again.',
      'details', jsonb_build_object('gps_freshness_minutes', 5)
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT public.fn_payment_compatible(v_driver_id, v_ride.payment_methods) THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'payment_incompatible', 'reason', 'payment_mismatch',
      'message', 'This ride uses a payment method you do not support.',
      'details', jsonb_build_object('ride_payment_methods', v_ride.payment_methods)
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'accepted',
      driver_id = v_driver_id,
      accepted_at = timezone('utc', now()),
      updated_at = now()
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'race_lost', 'reason', 'database_conflict',
      'message', 'Another driver accepted this ride first.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id <> v_driver_id
    AND i.status IN ('pending', 'wave_expired', 'expired');

  UPDATE public.ride_request_invites i
  SET status = 'accepted'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status IN ('pending', 'wave_expired', 'expired');

  INSERT INTO public.conversations (ride_request_id, driver_id, rider_identity_id)
  VALUES (p_ride_request_id, v_driver_id, v_ride.rider_identity_id)
  ON CONFLICT (ride_request_id) DO UPDATE
  SET driver_id = EXCLUDED.driver_id
  RETURNING id INTO v_conversation_id;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'driver_found',
    'Driver found',
    COALESCE(v_d.full_name, 'Your driver') || ' is on the way',
    jsonb_build_object(
      'type', 'driver_found',
      'ride_request_id', p_ride_request_id,
      'driver_name', v_d.full_name,
      'conversation_id', v_conversation_id
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.accepted', v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver', 'rpc', p_ride_request_id
  );

  PERFORM public.fn_taxi_terug_queue_accepted_invite(p_ride_request_id, v_driver_id);

    RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_accept_invite_diagnostic(uuid, uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_accept_invite_diagnostic(uuid, uuid, int) TO service_role;;
