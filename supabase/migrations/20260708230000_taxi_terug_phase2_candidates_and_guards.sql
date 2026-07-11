-- Taxi Terug Phase 2: candidates RPC, match score, 20 km suggest, anti-abuse guards.

-- Extend config defaults (merge into existing row when present).
UPDATE public.app_config
SET value = (
  COALESCE(NULLIF(btrim(value), '')::jsonb, '{}'::jsonb)
  || jsonb_build_object(
    'suggest_home_distance_km', 20,
    'min_match_score', 70,
    'destination_change_cooldown_hours', 4,
    'max_destination_changes_per_day', 3
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
    "max_destination_changes_per_day": 3
  }'::jsonb;
  v_raw text;
BEGIN
  SELECT value INTO v_raw
  FROM public.app_config
  WHERE key = 'terugtaxi_config';

  IF v_raw IS NULL OR btrim(v_raw) = '' THEN
    RETURN v_default;
  END IF;

  BEGIN
    RETURN v_default || v_raw::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN v_default;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_match_score(
  p_pickup_distance_km numeric,
  p_pickup_radius_km numeric,
  p_progress_km numeric,
  p_progress_ratio numeric,
  p_current_to_home_km numeric,
  p_destination_to_home_km numeric,
  p_driver_rating numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_direction numeric;
  v_pickup numeric;
  v_destination numeric;
  v_timing numeric := 1.0;
  v_quality numeric;
  v_total numeric;
  v_why text;
  v_dest_label numeric;
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

  v_quality := LEAST(
    GREATEST((COALESCE(p_driver_rating, 4.6) - 3.5) / 1.5, 0),
    1
  );

  v_total := round((
    v_direction * 40
    + v_pickup * 20
    + v_destination * 20
    + v_timing * 10
    + v_quality * 10
  )::numeric, 1);

  v_why := 'Closer to home after this trip';
  IF v_pickup >= 0.6 THEN
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
  v_dispatch_cfg jsonb := public.fn_dispatch_config();
  v_ride public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_loc record;
  v_current geography;
  v_home geography;
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
BEGIN
  IF COALESCE((v_cfg->>'enabled')::boolean, false) IS FALSE THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'disabled');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

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

  SELECT * INTO v_driver
  FROM public.drivers
  WHERE id = p_driver_id;

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

  SELECT dl.*
  INTO v_loc
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND dl.updated_at > now() - make_interval(
      mins => COALESCE((v_cfg->>'gps_freshness_minutes')::int, 5)
    )
  ORDER BY dl.updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'stale_location');
  END IF;

  v_pickup_radius_km := COALESCE(
    NULLIF(v_driver.pickup_distance_max_km, 0),
    (v_cfg->>'default_pickup_radius_km')::numeric,
    10
  );

  IF public.fn_dispatch_driver_eligible(
    p_driver_id,
    v_ride,
    v_ride.pickup_coords,
    v_pickup_radius_km,
    v_dispatch_cfg
  ) IS FALSE THEN
    RETURN jsonb_build_object('qualified', false, 'reason', 'not_dispatch_eligible');
  END IF;

  v_current :=
    ST_SetSRID(ST_MakePoint(v_loc.longitude, v_loc.latitude), 4326)::geography;
  v_home := ST_SetSRID(
    ST_MakePoint(
      v_driver.return_mode_destination_lng,
      v_driver.return_mode_destination_lat
    ),
    4326
  )::geography;

  v_pickup_distance_km := ST_Distance(v_current, v_ride.pickup_coords) / 1000.0;
  v_current_to_home_km := ST_Distance(v_current, v_home) / 1000.0;
  v_destination_to_home_km := ST_Distance(v_ride.destination_coords, v_home) / 1000.0;
  v_progress_km := v_current_to_home_km - v_destination_to_home_km;
  v_progress_ratio := CASE
    WHEN v_current_to_home_km <= 0 THEN 0
    ELSE v_progress_km / v_current_to_home_km
  END;
  v_min_progress_km := COALESCE((v_cfg->>'min_progress_km')::numeric, 3);
  v_min_progress_ratio := COALESCE((v_cfg->>'min_progress_ratio')::numeric, 0.08);
  v_min_match_score := COALESCE((v_cfg->>'min_match_score')::numeric, 70);

  v_score := public.fn_taxi_terug_match_score(
    v_pickup_distance_km,
    v_pickup_radius_km,
    v_progress_km,
    v_progress_ratio,
    v_current_to_home_km,
    v_destination_to_home_km,
    v_driver.rating
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
    'qualified', v_allowed,
    'reason', v_reason,
    'driver_id', p_driver_id,
    'ride_request_id', p_ride_request_id,
    'destination_label', v_driver.return_mode_destination_label,
    'pickup_distance_km', round(v_pickup_distance_km, 2),
    'pickup_radius_km', round(v_pickup_radius_km, 2),
    'current_to_home_km', round(v_current_to_home_km, 2),
    'destination_to_home_km', round(v_destination_to_home_km, 2),
    'progress_toward_home_km', round(v_progress_km, 2),
    'progress_ratio', round(v_progress_ratio, 4),
    'return_discount_pct', COALESCE(v_driver.active_return_discount_pct, 0),
    'match_score', v_match_score,
    'why_match', v_score->>'why_match',
    'pickup_detour_km', v_score->>'pickup_detour_km',
    'destination_fit', v_score->>'destination_fit',
    'timing_fit', v_score->>'timing_fit',
    'direction_score', v_score->>'direction_score',
    'pickup_score', v_score->>'pickup_score',
    'destination_score', v_score->>'destination_score'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_taxi_terug_candidates(
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_destination_lat double precision,
  p_destination_lng double precision,
  p_limit int DEFAULT 10
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
  v_destination :=
    ST_SetSRID(ST_MakePoint(p_destination_lng, p_destination_lat), 4326)::geography;
  v_trip_km := ST_Distance(v_pickup, v_destination) / 1000.0;
  v_default_radius := COALESCE((v_cfg->>'default_pickup_radius_km')::numeric, 10);
  v_min_progress_km := COALESCE((v_cfg->>'min_progress_km')::numeric, 3);
  v_min_progress_ratio := COALESCE((v_cfg->>'min_progress_ratio')::numeric, 0.08);
  v_min_match_score := COALESCE((v_cfg->>'min_match_score')::numeric, 70);
  v_eta_per_km := COALESCE((v_cfg->>'eta_minutes_per_km')::numeric, 2.2);

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
      rp.base_fare,
      rp.per_km_rate,
      rp.per_min_rate,
      rp.minimum_fare
    FROM public.drivers d
    JOIN public.driver_locations dl ON dl.driver_id = d.id
    LEFT JOIN LATERAL (
      SELECT p.base_fare, p.per_km_rate, p.per_min_rate, p.minimum_fare
      FROM public.driver_rate_profiles p
      WHERE p.driver_id = d.id AND p.is_active IS TRUE
      ORDER BY p.updated_at DESC NULLS LAST
      LIMIT 1
    ) rp ON true
    WHERE d.status = 'available'
      AND COALESCE(d.return_mode_enabled, false) IS TRUE
      AND d.return_mode_destination_lat IS NOT NULL
      AND d.return_mode_destination_lng IS NOT NULL
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - make_interval(
        mins => COALESCE((v_cfg->>'gps_freshness_minutes')::int, 5)
      )
      AND COALESCE((public.fn_driver_can_accept_rides(d.id)->>'allowed')::boolean, false) IS TRUE
  ),
  scored AS (
    SELECT
      b.*,
      ST_Distance(b.current_pos, v_pickup) / 1000.0 AS pickup_distance_km,
      ST_Distance(b.current_pos, b.home_pos) / 1000.0 AS current_to_home_km,
      ST_Distance(v_destination, b.home_pos) / 1000.0 AS destination_to_home_km
    FROM base b
  ),
  metrics AS (
    SELECT
      s.*,
      s.current_to_home_km - s.destination_to_home_km AS progress_km,
      CASE
        WHEN s.current_to_home_km <= 0 THEN 0
        ELSE (s.current_to_home_km - s.destination_to_home_km) / s.current_to_home_km
      END AS progress_ratio,
      GREATEST(
        round((s.pickup_distance_km * v_eta_per_km)::numeric, 0),
        1
      )::int AS pickup_eta_minutes,
      GREATEST(
        COALESCE(s.base_fare, 0)
        + COALESCE(s.per_km_rate, 0) * v_trip_km
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
        m.pickup_distance_km,
        m.pickup_radius_km,
        m.progress_km,
        m.progress_ratio,
        m.current_to_home_km,
        m.destination_to_home_km,
        m.driver_rating
      ) AS score_payload
    FROM metrics m
    WHERE m.progress_km >= v_min_progress_km
      AND m.progress_ratio >= v_min_progress_ratio
  ),
  ranked AS (
    SELECT
      q.driver_id,
      q.driver_first_name,
      q.vehicle_label,
      q.driver_rating,
      q.heading_to,
      q.pickup_eta_minutes,
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
      'driver_rating', round(r.driver_rating::numeric, 1)
    )
  ), '[]'::jsonb)
  INTO v_candidates
  FROM ranked r;

  RETURN jsonb_build_object(
    'enabled', true,
    'trip_distance_km', round(v_trip_km, 1),
    'candidate_count', COALESCE(jsonb_array_length(v_candidates), 0),
    'candidates', v_candidates
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_return_mode_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver record;
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_destination_label text;
  v_pickup_radius numeric;
  v_discount numeric;
  v_can_prompt boolean;
  v_km_from_home numeric;
  v_suggest_home_km numeric;
  v_suggest_taxi_terug boolean;
  v_loc record;
  v_home geography;
BEGIN
  SELECT
    d.id,
    d.return_mode_enabled,
    d.return_mode_auto_accept_enabled,
    d.return_mode_destination_zone_id,
    d.return_mode_destination_label,
    d.return_mode_destination_lat,
    d.return_mode_destination_lng,
    d.return_mode_activated_at,
    d.return_mode_disabled_at,
    d.return_mode_last_prompt_at,
    d.return_mode_prompt_dismissed_until,
    d.heading_home_zone_id,
    d.home_city,
    d.pickup_distance_max_km,
    d.active_return_discount_pct
  INTO v_driver
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_not_found');
  END IF;

  v_destination_label := nullif(trim(coalesce(
    v_driver.return_mode_destination_label,
    v_driver.home_city,
    ''
  )), '');
  v_pickup_radius := coalesce(v_driver.pickup_distance_max_km, 10);
  v_discount := coalesce(v_driver.active_return_discount_pct, 0);
  v_suggest_home_km := coalesce((v_cfg->>'suggest_home_distance_km')::numeric, 20);
  v_km_from_home := NULL;

  IF v_driver.return_mode_destination_lat IS NOT NULL
     AND v_driver.return_mode_destination_lng IS NOT NULL THEN
    SELECT dl.latitude, dl.longitude
    INTO v_loc
    FROM public.driver_locations dl
    WHERE dl.driver_id = v_driver.id
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
    ORDER BY dl.updated_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_home := ST_SetSRID(
        ST_MakePoint(v_driver.return_mode_destination_lng, v_driver.return_mode_destination_lat),
        4326
      )::geography;
      v_km_from_home := round(
        ST_Distance(
          ST_SetSRID(ST_MakePoint(v_loc.longitude, v_loc.latitude), 4326)::geography,
          v_home
        ) / 1000.0,
        1
      );
    END IF;
  END IF;

  v_suggest_taxi_terug :=
    coalesce(v_driver.return_mode_enabled, false) IS FALSE
    AND v_destination_label IS NOT NULL
    AND v_km_from_home IS NOT NULL
    AND v_km_from_home >= v_suggest_home_km;

  v_can_prompt :=
    v_suggest_taxi_terug
    AND (
      v_driver.return_mode_prompt_dismissed_until IS NULL
      OR v_driver.return_mode_prompt_dismissed_until <= now()
    );

  RETURN jsonb_build_object(
    'ok', true,
    'enabled', coalesce(v_driver.return_mode_enabled, false),
    'auto_accept_enabled', coalesce(v_driver.return_mode_auto_accept_enabled, false),
    'destination_zone_id', coalesce(
      v_driver.return_mode_destination_zone_id,
      v_driver.heading_home_zone_id
    ),
    'destination_label', v_destination_label,
    'destination_lat', v_driver.return_mode_destination_lat,
    'destination_lng', v_driver.return_mode_destination_lng,
    'pickup_radius_km', v_pickup_radius,
    'return_discount_pct', v_discount,
    'activated_at', v_driver.return_mode_activated_at,
    'disabled_at', v_driver.return_mode_disabled_at,
    'last_prompt_at', v_driver.return_mode_last_prompt_at,
    'prompt_dismissed_until', v_driver.return_mode_prompt_dismissed_until,
    'can_prompt', v_can_prompt,
    'km_from_home', v_km_from_home,
    'suggest_taxi_terug', v_suggest_taxi_terug,
    'suggest_home_distance_km', v_suggest_home_km
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_return_mode_activate(
  p_destination_label text DEFAULT NULL,
  p_destination_zone_id uuid DEFAULT NULL,
  p_destination_lat double precision DEFAULT NULL,
  p_destination_lng double precision DEFAULT NULL,
  p_pickup_radius_km numeric DEFAULT NULL,
  p_return_discount_pct numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver record;
  v_profile_id uuid;
  v_destination_label text;
  v_pickup_radius numeric;
  v_discount numeric;
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_cooldown_hours int;
  v_max_daily int;
  v_activations_today int;
  v_last_activation record;
  v_destination_changed boolean;
BEGIN
  SELECT
    d.id,
    d.home_city,
    d.pickup_distance_max_km,
    d.active_return_discount_pct,
    d.return_mode_destination_label,
    d.return_mode_destination_lat,
    d.return_mode_destination_lng
  INTO v_driver
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'driver_not_found');
  END IF;

  v_destination_label := nullif(trim(coalesce(
    p_destination_label,
    v_driver.home_city,
    ''
  )), '');
  IF v_destination_label IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_return_destination');
  END IF;

  v_cooldown_hours := COALESCE((v_cfg->>'destination_change_cooldown_hours')::int, 4);
  v_max_daily := COALESCE((v_cfg->>'max_destination_changes_per_day')::int, 3);

  SELECT e.payload, e.created_at
  INTO v_last_activation
  FROM public.driver_return_mode_events e
  WHERE e.driver_id = v_driver.id
    AND e.event_type = 'return_mode.activated'
  ORDER BY e.created_at DESC
  LIMIT 1;

  v_destination_changed :=
    v_last_activation.payload IS NOT NULL
    AND (
      coalesce(v_last_activation.payload->>'destination_label', '') IS DISTINCT FROM v_destination_label
      OR (
        p_destination_lat IS NOT NULL
        AND p_destination_lng IS NOT NULL
        AND (
          coalesce((v_last_activation.payload->>'destination_lat')::double precision, 0)
            IS DISTINCT FROM p_destination_lat
          OR coalesce((v_last_activation.payload->>'destination_lng')::double precision, 0)
            IS DISTINCT FROM p_destination_lng
        )
      )
    );

  IF v_destination_changed
     AND v_last_activation.created_at > now() - make_interval(hours => v_cooldown_hours) THEN
    INSERT INTO public.driver_return_mode_events (driver_id, event_type, payload)
    VALUES (
      v_driver.id,
      'return_mode.dismissed',
      jsonb_build_object('reason', 'destination_cooldown', 'attempted_label', v_destination_label)
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'destination_cooldown',
      'retry_after_hours', v_cooldown_hours
    );
  END IF;

  SELECT count(*)::int INTO v_activations_today
  FROM public.driver_return_mode_events e
  WHERE e.driver_id = v_driver.id
    AND e.event_type = 'return_mode.activated'
    AND e.created_at >= date_trunc('day', now());

  IF v_destination_changed AND v_activations_today >= v_max_daily THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'daily_destination_change_limit',
      'max_per_day', v_max_daily
    );
  END IF;

  v_pickup_radius := least(greatest(coalesce(
    p_pickup_radius_km,
    v_driver.pickup_distance_max_km,
    10
  ), 1), 50);
  v_discount := least(greatest(coalesce(
    p_return_discount_pct,
    nullif(v_driver.active_return_discount_pct, 0),
    15
  ), 0), 40);

  UPDATE public.drivers d
  SET
    return_mode_enabled = true,
    return_mode_auto_accept_enabled = false,
    return_mode_destination_label = v_destination_label,
    return_mode_destination_zone_id = p_destination_zone_id,
    return_mode_destination_lat = p_destination_lat,
    return_mode_destination_lng = p_destination_lng,
    return_mode_activated_at = now(),
    return_mode_disabled_at = null,
    pickup_distance_max_km = v_pickup_radius,
    updated_at = now()
  WHERE d.id = v_driver.id;

  SELECT p.id INTO v_profile_id
  FROM public.driver_rate_profiles p
  WHERE p.driver_id = v_driver.id AND p.is_active IS TRUE
  ORDER BY p.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    UPDATE public.driver_rate_profiles p
    SET return_discount_pct = v_discount,
        updated_at = now()
    WHERE p.id = v_profile_id;
  ELSE
    UPDATE public.drivers d
    SET active_return_discount_pct = v_discount
    WHERE d.id = v_driver.id;
  END IF;

  INSERT INTO public.driver_return_mode_events (driver_id, event_type, payload)
  VALUES (
    v_driver.id,
    'return_mode.activated',
    jsonb_build_object(
      'destination_label', v_destination_label,
      'destination_zone_id', p_destination_zone_id,
      'destination_lat', p_destination_lat,
      'destination_lng', p_destination_lng,
      'pickup_radius_km', v_pickup_radius,
      'return_discount_pct', v_discount,
      'auto_accept_enabled', false,
      'destination_changed', v_destination_changed
    )
  );

  RETURN public.fn_driver_return_mode_status();
END;
$$;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_candidates(double precision, double precision, double precision, double precision, int) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_candidates(double precision, double precision, double precision, double precision, int) TO anon, authenticated, service_role;
