-- TAXI TERUG booking mode contract.
-- Surgical addition: reuse marketplace-style ride_requests, existing Return Mode,
-- existing dispatch eligibility, and existing invite lifecycle.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'booking_mode'
      AND e.enumlabel = 'terug'
  ) THEN
    ALTER TYPE public.booking_mode ADD VALUE 'terug';
  END IF;
END $$;

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS return_mode_origin_ride_id uuid
  REFERENCES public.ride_requests(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_drivers_return_mode_active
  ON public.drivers (return_mode_enabled, status)
  WHERE return_mode_enabled IS TRUE;

COMMENT ON COLUMN public.drivers.return_mode_origin_ride_id IS
  'Optional ride that triggered the post-trip TAXI TERUG prompt.';

ALTER TABLE public.ride_requests
  DROP CONSTRAINT IF EXISTS chk_marketplace_requires_fare;

ALTER TABLE public.ride_requests
  ADD CONSTRAINT chk_marketplace_requires_fare
  CHECK (
    booking_mode::text <> ALL (ARRAY['marketplace', 'terug'])
    OR marketplace_offered_fare IS NOT NULL
  );

INSERT INTO public.app_config(key, value)
VALUES (
  'terugtaxi_config',
  '{
    "enabled": false,
    "gps_freshness_minutes": 5,
    "default_pickup_radius_km": 10,
    "default_discount_pct": 15,
    "min_progress_km": 3,
    "min_progress_ratio": 0.08,
    "invite_window_seconds": 30,
    "max_invites_per_wave": 5,
    "eta_minutes_per_km": 2.2
  }'
)
ON CONFLICT (key) DO NOTHING;

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
    "eta_minutes_per_km": 2.2
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
  EXCEPTION WHEN others THEN
    RETURN v_default;
  END;
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
  v_allowed boolean := false;
  v_reason text := 'unknown';
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

  IF v_pickup_distance_km > v_pickup_radius_km THEN
    v_reason := 'outside_pickup_radius';
  ELSIF v_progress_km < v_min_progress_km THEN
    v_reason := 'not_enough_progress_home';
  ELSIF v_progress_ratio < v_min_progress_ratio THEN
    v_reason := 'wrong_direction';
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
    'return_discount_pct', COALESCE(v_driver.active_return_discount_pct, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_taxi_terug_supply(
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_destination_lat double precision,
  p_destination_lng double precision
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
  v_enabled boolean;
  v_count int := 0;
  v_nearest_km numeric;
  v_best_progress_km numeric;
  v_default_radius numeric;
  v_min_progress_km numeric;
  v_min_progress_ratio numeric;
BEGIN
  v_enabled := COALESCE((v_cfg->>'enabled')::boolean, false);
  IF v_enabled IS FALSE THEN
    RETURN jsonb_build_object(
      'enabled', false,
      'available_drivers', 0,
      'reason', 'disabled'
    );
  END IF;

  IF p_pickup_lat IS NULL OR p_pickup_lng IS NULL
     OR p_destination_lat IS NULL OR p_destination_lng IS NULL THEN
    RETURN jsonb_build_object(
      'enabled', true,
      'available_drivers', 0,
      'reason', 'missing_route'
    );
  END IF;

  v_pickup := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  v_destination :=
    ST_SetSRID(ST_MakePoint(p_destination_lng, p_destination_lat), 4326)::geography;
  v_default_radius := COALESCE((v_cfg->>'default_pickup_radius_km')::numeric, 10);
  v_min_progress_km := COALESCE((v_cfg->>'min_progress_km')::numeric, 3);
  v_min_progress_ratio := COALESCE((v_cfg->>'min_progress_ratio')::numeric, 0.08);

  WITH candidates AS (
    SELECT
      d.id,
      ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography AS current_pos,
      ST_SetSRID(
        ST_MakePoint(d.return_mode_destination_lng, d.return_mode_destination_lat),
        4326
      )::geography AS home_pos,
      COALESCE(NULLIF(d.pickup_distance_max_km, 0), v_default_radius) AS pickup_radius_km
    FROM public.drivers d
    JOIN public.driver_locations dl ON dl.driver_id = d.id
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
      c.id,
      ST_Distance(c.current_pos, v_pickup) / 1000.0 AS pickup_distance_km,
      ST_Distance(c.current_pos, c.home_pos) / 1000.0 AS current_to_home_km,
      ST_Distance(v_destination, c.home_pos) / 1000.0 AS destination_to_home_km,
      c.pickup_radius_km
    FROM candidates c
  ),
  qualified AS (
    SELECT
      s.*,
      s.current_to_home_km - s.destination_to_home_km AS progress_km,
      CASE
        WHEN s.current_to_home_km <= 0 THEN 0
        ELSE (s.current_to_home_km - s.destination_to_home_km) / s.current_to_home_km
      END AS progress_ratio
    FROM scored s
    WHERE s.pickup_distance_km <= s.pickup_radius_km
  )
  SELECT
    COUNT(*)::int,
    round(MIN(pickup_distance_km)::numeric, 2),
    round(MAX(progress_km)::numeric, 2)
  INTO v_count, v_nearest_km, v_best_progress_km
  FROM qualified q
  WHERE q.progress_km >= v_min_progress_km
    AND q.progress_ratio >= v_min_progress_ratio;

  RETURN jsonb_build_object(
    'enabled', true,
    'available_drivers', COALESCE(v_count, 0),
    'nearest_pickup_km', v_nearest_km,
    'best_progress_toward_home_km', v_best_progress_km,
    'default_discount_pct', COALESCE((v_cfg->>'default_discount_pct')::numeric, 15),
    'default_pickup_radius_km', v_default_radius
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_seed_taxi_terug_matching_batch(
  p_ride_request_id uuid,
  p_batch_size int DEFAULT NULL,
  p_window_seconds int DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_ride public.ride_requests%ROWTYPE;
  v_next_batch int;
  v_inserted int;
  v_window_seconds int;
  v_max_invites int;
  v_eta_per_km numeric;
  v_state jsonb;
  v_metrics jsonb;
BEGIN
  IF COALESCE((v_cfg->>'enabled')::boolean, false) IS FALSE THEN
    RETURN json_build_object('ok', false, 'error', 'taxi_terug_disabled');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'wave_expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending'
    AND i.expires_at <= now();

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_pending');
  END IF;

  IF v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN json_build_object('ok', false, 'error', 'not_taxi_terug');
  END IF;

  IF v_ride.pickup_coords IS NULL OR v_ride.destination_coords IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_route');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN json_build_object('ok', true, 'skipped', true, 'reason', 'active_invites');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.status = 'accepted'
  ) THEN
    RETURN json_build_object('ok', true, 'skipped', true, 'reason', 'already_accepted');
  END IF;

  SELECT COALESCE(MAX(i.batch_no), 0) + 1 INTO v_next_batch
  FROM public.ride_request_invites i
  WHERE i.ride_request_id = p_ride_request_id;

  v_window_seconds := COALESCE(
    p_window_seconds,
    (v_cfg->>'invite_window_seconds')::int,
    30
  );
  v_max_invites := COALESCE(
    p_batch_size,
    (v_cfg->>'max_invites_per_wave')::int,
    5
  );
  v_eta_per_km := COALESCE((v_cfg->>'eta_minutes_per_km')::numeric, 2.2);

  WITH qualified AS (
    SELECT
      d.id AS driver_id,
      (public.fn_terugtaxi_qualify(d.id, p_ride_request_id)) AS q
    FROM public.drivers d
    WHERE COALESCE(d.return_mode_enabled, false) IS TRUE
  ),
  scored AS (
    SELECT
      q.driver_id,
      (q.q->>'pickup_distance_km')::numeric AS pickup_distance_km,
      (q.q->>'progress_toward_home_km')::numeric AS progress_km,
      round(
        (
          100
          - LEAST((q.q->>'pickup_distance_km')::numeric * 3, 50)
          + LEAST((q.q->>'progress_toward_home_km')::numeric * 1.5, 50)
        )::numeric,
        2
      ) AS composite_score
    FROM qualified q
    WHERE COALESCE((q.q->>'qualified')::boolean, false) IS TRUE
  ),
  inserted AS (
    INSERT INTO public.ride_request_invites (
      ride_request_id,
      driver_id,
      batch_no,
      invited_at,
      expires_at,
      status,
      composite_score,
      distance_km,
      eta_minutes
    )
    SELECT
      p_ride_request_id,
      s.driver_id,
      v_next_batch,
      now(),
      now() + make_interval(secs => v_window_seconds),
      'pending',
      s.composite_score,
      round(s.pickup_distance_km, 2),
      round((s.pickup_distance_km * v_eta_per_km)::numeric, 1)
    FROM scored s
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites x
      WHERE x.ride_request_id = p_ride_request_id
        AND x.driver_id = s.driver_id
    )
    ORDER BY s.composite_score DESC, s.pickup_distance_km ASC
    LIMIT v_max_invites
    ON CONFLICT (ride_request_id, driver_id) DO NOTHING
    RETURNING driver_id, composite_score, distance_km, eta_minutes
  )
  INSERT INTO public.driver_return_mode_events(driver_id, event_type, payload)
  SELECT
    i.driver_id,
    'return_ride.qualified',
    jsonb_build_object(
      'ride_request_id', p_ride_request_id,
      'batch_no', v_next_batch,
      'composite_score', i.composite_score,
      'distance_km', i.distance_km,
      'eta_minutes', i.eta_minutes
    )
  FROM inserted i;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  v_state := COALESCE(v_ride.dispatch_state, '{}'::jsonb) || jsonb_build_object(
    'last_wave', v_next_batch,
    'last_batch', v_next_batch,
    'taxi_terug', true,
    'wave_timeout_seconds', v_window_seconds,
    'max_invites', v_max_invites
  );

  UPDATE public.ride_requests rr
  SET dispatch_state = v_state,
      updated_at = now()
  WHERE rr.id = p_ride_request_id;

  v_metrics := jsonb_build_object(
    'batch_no', v_next_batch,
    'invited', v_inserted,
    'timeout_seconds', v_window_seconds,
    'dispatch_version', 'taxi_terug_v1'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'dispatch.taxi_terug_wave_seeded',
    NULL,
    v_metrics,
    'system',
    'supabase_taxi_terug',
    p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'wave', v_next_batch,
    'batch_no', v_next_batch,
    'invited', v_inserted,
    'metrics', v_metrics,
    'dispatch_version', 'taxi_terug_v1'
  );
END;
$$;

DO $$
BEGIN
  IF to_regprocedure('public.fn_seed_ride_matching_batch_dispatch_v3(uuid, integer, integer)') IS NULL
     AND to_regprocedure('public.fn_seed_ride_matching_batch(uuid, integer, integer)') IS NOT NULL THEN
    ALTER FUNCTION public.fn_seed_ride_matching_batch(uuid, integer, integer)
      RENAME TO fn_seed_ride_matching_batch_dispatch_v3;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch(
  p_ride_request_id uuid,
  p_batch_size int DEFAULT NULL,
  p_window_seconds int DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mode text;
BEGIN
  SELECT booking_mode::text INTO v_mode
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF v_mode = 'terug' THEN
    RETURN public.fn_seed_taxi_terug_matching_batch(
      p_ride_request_id,
      p_batch_size,
      p_window_seconds
    );
  END IF;

  RETURN public.fn_seed_ride_matching_batch_dispatch_v3(
    p_ride_request_id,
    p_batch_size,
    p_window_seconds
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch(
  p_ride_request_id uuid,
  p_batch_no integer DEFAULT 1
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  v_result := public.fn_seed_ride_matching_batch(
    p_ride_request_id,
    NULL::int,
    NULL::int
  );

  RETURN COALESCE((v_result::jsonb->>'invited')::integer, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_config() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_terugtaxi_qualify(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_supply(double precision, double precision, double precision, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_seed_taxi_terug_matching_batch(uuid, int, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_seed_ride_matching_batch(uuid, int, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_config() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_terugtaxi_qualify(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_supply(double precision, double precision, double precision, double precision) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_seed_taxi_terug_matching_batch(uuid, int, int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch(uuid, int, int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer) TO authenticated, service_role;
