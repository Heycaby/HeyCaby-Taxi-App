-- SDA v1.0 — zone-based, wave-driven, composite-scored driver matching.
-- Tunable via app_config.dispatch_config. Preserves scheduled deferral, billing,
-- vehicle/pet filters, payment compatibility, and accept RPC contracts.

-- ---------------------------------------------------------------------------
-- Config seed
-- ---------------------------------------------------------------------------
INSERT INTO public.app_config (key, value)
VALUES (
  'dispatch_config',
  '{
    "sda_v1_enabled": true,
    "wave1_radius_km": 5,
    "wave2_radius_km": 10,
    "wave3_radius_km": 20,
    "wave4_radius_km": 35,
    "wave1_timeout_seconds": 10,
    "wave2_timeout_seconds": 12,
    "wave3_timeout_seconds": 15,
    "wave4_timeout_seconds": 20,
    "max_invites_per_wave": 5,
    "my_drivers_window_seconds": 15,
    "surge_demand_ratio": 3.0,
    "surge_max_invites": 8,
    "surge_wave1_radius_km": 8,
    "surge_wave1_timeout_seconds": 7,
    "night_mode_start_hour": 22,
    "night_mode_end_hour": 6,
    "night_wave1_radius_km": 8,
    "night_wave1_timeout_seconds": 15,
    "night_max_radius_km": 50,
    "rush_wave4_radius_km": 40,
    "rush_morning_start": "07:30",
    "rush_morning_end": "09:00",
    "rush_evening_start": "16:30",
    "rush_evening_end": "18:30",
    "score_weight_distance": 0.45,
    "score_weight_eta": 0.35,
    "score_weight_rating": 0.12,
    "score_weight_tariff": 0.08,
    "gps_freshness_minutes": 3,
    "min_rating": 4.0,
    "low_density_wave1_threshold": 3,
    "eta_minutes_per_km": 2.2,
    "tariff_reference_per_km": 3.0
  }'::jsonb
)
ON CONFLICT (key) DO UPDATE
SET value = public.app_config.value || EXCLUDED.value;

-- ---------------------------------------------------------------------------
-- Ride dispatch state + invite status extension
-- ---------------------------------------------------------------------------
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS dispatch_state jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.ride_requests.dispatch_state IS
  'SDA wave metadata: collapsed_waves_1_2, surge, night, last_wave, etc.';

ALTER TABLE public.ride_request_invites
  DROP CONSTRAINT IF EXISTS ride_request_invites_status_check;

ALTER TABLE public.ride_request_invites
  ADD CONSTRAINT ride_request_invites_status_check
  CHECK (status IN (
    'pending',
    'expired',
    'wave_expired',
    'accepted',
    'superseded'
  ));

ALTER TABLE public.ride_request_invites
  ADD COLUMN IF NOT EXISTS composite_score numeric,
  ADD COLUMN IF NOT EXISTS distance_km numeric,
  ADD COLUMN IF NOT EXISTS eta_minutes numeric;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_dispatch_config()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_defaults jsonb := '{
    "sda_v1_enabled": true,
    "wave1_radius_km": 5,
    "wave2_radius_km": 10,
    "wave3_radius_km": 20,
    "wave4_radius_km": 35,
    "wave1_timeout_seconds": 10,
    "wave2_timeout_seconds": 12,
    "wave3_timeout_seconds": 15,
    "wave4_timeout_seconds": 20,
    "max_invites_per_wave": 5,
    "my_drivers_window_seconds": 15,
    "surge_demand_ratio": 3.0,
    "surge_max_invites": 8,
    "surge_wave1_radius_km": 8,
    "surge_wave1_timeout_seconds": 7,
    "night_mode_start_hour": 22,
    "night_mode_end_hour": 6,
    "night_wave1_radius_km": 8,
    "night_wave1_timeout_seconds": 15,
    "night_max_radius_km": 50,
    "rush_wave4_radius_km": 40,
    "rush_morning_start": "07:30",
    "rush_morning_end": "09:00",
    "rush_evening_start": "16:30",
    "rush_evening_end": "18:30",
    "score_weight_distance": 0.45,
    "score_weight_eta": 0.35,
    "score_weight_rating": 0.12,
    "score_weight_tariff": 0.08,
    "gps_freshness_minutes": 3,
    "min_rating": 4.0,
    "low_density_wave1_threshold": 3,
    "eta_minutes_per_km": 2.2,
    "tariff_reference_per_km": 3.0
  }'::jsonb;
BEGIN
  RETURN v_defaults || COALESCE(public.fn_app_config_jsonb('dispatch_config'), '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_dispatch_is_night_mode(p_cfg jsonb DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := COALESCE(p_cfg, public.fn_dispatch_config());
  v_hour int := EXTRACT(HOUR FROM timezone('Europe/Amsterdam', now()))::int;
  v_start int := COALESCE((v_cfg->>'night_mode_start_hour')::int, 22);
  v_end int := COALESCE((v_cfg->>'night_mode_end_hour')::int, 6);
BEGIN
  IF v_start <= v_end THEN
    RETURN v_hour >= v_start AND v_hour < v_end;
  END IF;
  RETURN v_hour >= v_start OR v_hour < v_end;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_dispatch_is_rush_hour(p_cfg jsonb DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := COALESCE(p_cfg, public.fn_dispatch_config());
  v_now time := timezone('Europe/Amsterdam', now())::time;
BEGIN
  RETURN (
    v_now >= COALESCE((v_cfg->>'rush_morning_start')::time, time '07:30')
    AND v_now < COALESCE((v_cfg->>'rush_morning_end')::time, time '09:00')
  ) OR (
    v_now >= COALESCE((v_cfg->>'rush_evening_start')::time, time '16:30')
    AND v_now < COALESCE((v_cfg->>'rush_evening_end')::time, time '18:30')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_dispatch_surge_active(p_cfg jsonb DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := COALESCE(p_cfg, public.fn_dispatch_config());
  v_ratio numeric := COALESCE((v_cfg->>'surge_demand_ratio')::numeric, 3.0);
  v_pending int;
  v_available int;
BEGIN
  SELECT COUNT(*) INTO v_pending
  FROM public.ride_requests rr
  WHERE rr.status = 'pending'
    AND rr.driver_id IS NULL
    AND rr.created_at >= now() - interval '30 minutes';

  SELECT COUNT(*) INTO v_available
  FROM public.drivers d
  INNER JOIN public.driver_locations dl ON dl.driver_id = d.id
  WHERE d.status = 'available'
    AND dl.updated_at > now() - make_interval(
      mins => COALESCE((v_cfg->>'gps_freshness_minutes')::int, 3)
    );

  IF v_available <= 0 THEN
    RETURN v_pending > 0;
  END IF;

  RETURN (v_pending::numeric / v_available::numeric) > v_ratio;
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
  v_rating numeric;
  v_gps_mins int := COALESCE((p_cfg->>'gps_freshness_minutes')::int, 3);
  v_min_rating numeric := COALESCE((p_cfg->>'min_rating')::numeric, 4.0);
  v_has_vehicle_photo boolean;
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

  v_rating := COALESCE(v_d.avg_rating, v_d.rating, 5.0);
  v_has_vehicle_photo := length(trim(COALESCE(v_d.vehicle_photo_front_url, ''))) > 0
    OR length(trim(COALESCE(v_d.vehicle_photo_rear_url, ''))) > 0
    OR COALESCE(array_length(v_d.vehicle_photo_urls, 1), 0) > 0;

  IF v_d.status IS DISTINCT FROM 'available' THEN
    RETURN false;
  END IF;
  -- Go-online already enforced profile/vehicle readiness; do not double-gate here.
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

-- ---------------------------------------------------------------------------
-- Legacy fallback (distance-only batches) when SDA disabled
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch_legacy (
  p_ride_request_id uuid,
  p_batch_size int DEFAULT 4,
  p_window_seconds int DEFAULT 30
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride record;
  v_pickup geography;
  v_next_batch int;
  v_inserted int;
BEGIN
  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending'
    AND i.expires_at <= now();

  SELECT * INTO v_ride FROM public.ride_requests r WHERE r.id = p_ride_request_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_pending');
  END IF;

  v_pickup := v_ride.pickup_coords;
  IF v_pickup IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'no_pickup');
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

  SELECT COALESCE(MAX(i.batch_no), 0) + 1 INTO v_next_batch
  FROM public.ride_request_invites i
  WHERE i.ride_request_id = p_ride_request_id;

  IF v_next_batch > 20 THEN
    RETURN json_build_object('ok', false, 'error', 'max_batches');
  END IF;

  INSERT INTO public.ride_request_invites (
    ride_request_id, driver_id, batch_no, expires_at, status
  )
  SELECT
    p_ride_request_id,
    dl.driver_id,
    v_next_batch,
    now() + make_interval(secs => p_window_seconds),
    'pending'
  FROM public.driver_locations dl
  INNER JOIN public.drivers d ON d.id = dl.driver_id
  LEFT JOIN public.rider_favorite_drivers rfd
    ON rfd.driver_id = d.id
    AND rfd.rider_identity_id = v_ride.rider_identity_id
  WHERE d.status = 'available'
    AND dl.updated_at > now() - interval '3 minutes'
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND COALESCE((public.fn_driver_can_accept_rides(dl.driver_id)->>'allowed')::boolean, false) = true
    AND public.fn_payment_compatible(dl.driver_id, v_ride.payment_methods)
    AND NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites x
      WHERE x.ride_request_id = p_ride_request_id
        AND x.driver_id = dl.driver_id
    )
  ORDER BY
    CASE
      WHEN COALESCE(v_ride.favorites_first, false) THEN
        CASE WHEN rfd.driver_id IS NOT NULL THEN 0 ELSE 1 END
      ELSE 0
    END ASC,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
      v_pickup
    ) ASC NULLS LAST
  LIMIT p_batch_size;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN json_build_object(
    'ok', true,
    'batch', v_next_batch,
    'invited', v_inserted,
    'dispatch_version', 1
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- SDA v1 seed / advance one wave
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch (
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
  v_cfg jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_pickup geography;
  v_next_batch int;
  v_inserted int;
  v_metrics jsonb;
  v_t0 timestamptz;
  v_t1 timestamptz;
  v_duration_ms numeric;
  v_scheduled_lead_minutes int;
  v_matching_starts_at timestamptz;
  v_gps_mins int;
  v_max_radius_km numeric;
  v_wave int;
  v_inner_km numeric := 0;
  v_outer_km numeric;
  v_timeout int;
  v_max_invites int;
  v_night boolean;
  v_surge boolean;
  v_rush boolean;
  v_collapsed boolean := false;
  v_state jsonb;
  v_wave1_count int := 0;
  v_favorite_only boolean := false;
  v_favorite_name text;
  v_w_dist numeric;
  v_w_eta numeric;
  v_w_rating numeric;
  v_w_tariff numeric;
  v_tariff_ref numeric;
  v_eta_per_km numeric;
BEGIN
  v_t0 := clock_timestamp();
  v_cfg := public.fn_dispatch_config();

  IF COALESCE((v_cfg->>'sda_v1_enabled')::boolean, true) = false THEN
    RETURN public.fn_seed_ride_matching_batch_legacy(
      p_ride_request_id,
      COALESCE(p_batch_size, 4),
      COALESCE(p_window_seconds, 30)
    );
  END IF;

  v_gps_mins := COALESCE((v_cfg->>'gps_freshness_minutes')::int, 3);
  v_night := public.fn_dispatch_is_night_mode(v_cfg);
  v_surge := public.fn_dispatch_surge_active(v_cfg);
  v_rush := public.fn_dispatch_is_rush_hour(v_cfg);
  v_w_dist := COALESCE((v_cfg->>'score_weight_distance')::numeric, 0.45);
  v_w_eta := COALESCE((v_cfg->>'score_weight_eta')::numeric, 0.35);
  v_w_rating := COALESCE((v_cfg->>'score_weight_rating')::numeric, 0.12);
  v_w_tariff := COALESCE((v_cfg->>'score_weight_tariff')::numeric, 0.08);
  v_tariff_ref := COALESCE((v_cfg->>'tariff_reference_per_km')::numeric, 3.0);
  v_eta_per_km := COALESCE((v_cfg->>'eta_minutes_per_km')::numeric, 2.2);
  v_max_invites := COALESCE(p_batch_size, (v_cfg->>'max_invites_per_wave')::int, 5);
  IF v_surge THEN
    v_max_invites := greatest(v_max_invites, COALESCE((v_cfg->>'surge_max_invites')::int, 8));
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'wave_expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending'
    AND i.expires_at <= now();

  SELECT * INTO v_ride
  FROM public.ride_requests r
  WHERE r.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_pending');
  END IF;

  IF v_ride.booking_mode IS NOT DISTINCT FROM 'scheduled'
     AND v_ride.scheduled_pickup_at IS NOT NULL THEN
    v_scheduled_lead_minutes := public.fn_scheduled_matching_lead_minutes();
    v_matching_starts_at :=
      v_ride.scheduled_pickup_at - make_interval(mins => v_scheduled_lead_minutes);

    IF v_matching_starts_at > now() THEN
      RETURN json_build_object(
        'ok', true,
        'skipped', true,
        'reason', 'scheduled_deferred',
        'scheduled_pickup_at', v_ride.scheduled_pickup_at,
        'matching_starts_at', v_matching_starts_at
      );
    END IF;
  END IF;

  v_pickup := v_ride.pickup_coords;
  IF v_pickup IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'no_pickup');
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

  v_state := COALESCE(v_ride.dispatch_state, '{}'::jsonb);
  v_collapsed := COALESCE((v_state->>'collapsed_waves_1_2')::boolean, false);

  SELECT COALESCE(MAX(i.batch_no), -1) INTO v_next_batch
  FROM public.ride_request_invites i
  WHERE i.ride_request_id = p_ride_request_id;

  IF v_next_batch >= 0 THEN
    v_wave := v_next_batch + 1;
    IF v_collapsed AND v_wave = 2 THEN
      v_wave := 3;
    END IF;
  ELSIF COALESCE(v_ride.favorites_first, false)
        AND EXISTS (
          SELECT 1
          FROM public.rider_favorite_drivers rfd
          INNER JOIN public.drivers d ON d.id = rfd.driver_id
          WHERE rfd.rider_identity_id = v_ride.rider_identity_id
            AND public.fn_dispatch_driver_eligible(
              d.id, v_ride, v_pickup,
              CASE
                WHEN v_night THEN COALESCE((v_cfg->>'night_max_radius_km')::numeric, 50)
                ELSE COALESCE((v_cfg->>'wave4_radius_km')::numeric, 35)
              END,
              v_cfg
            )
        ) THEN
    v_wave := 0;
    v_next_batch := 0;
  ELSE
    v_wave := 1;
    v_next_batch := 1;
  END IF;

  v_max_radius_km := COALESCE((v_cfg->>'wave4_radius_km')::numeric, 35);
  IF v_night THEN
    v_max_radius_km := COALESCE((v_cfg->>'night_max_radius_km')::numeric, 50);
  ELSIF v_rush THEN
    v_max_radius_km := greatest(
      v_max_radius_km,
      COALESCE((v_cfg->>'rush_wave4_radius_km')::numeric, 40)
    );
  END IF;

  IF v_wave > 4 THEN
    UPDATE public.ride_requests rr
    SET status = 'expired',
        dispatch_state = v_state || jsonb_build_object(
          'terminal', 'no_drivers_found',
          'completed_at', to_jsonb(now())
        ),
        updated_at = now()
    WHERE rr.id = p_ride_request_id
      AND rr.status = 'pending';

    PERFORM public.fn_ride_audit_append(
      p_ride_request_id,
      'dispatch.no_drivers_found',
      NULL,
      jsonb_build_object('wave', v_wave, 'dispatch_version', 3),
      'system',
      'supabase_sda',
      p_ride_request_id
    );

    RETURN json_build_object(
      'ok', true,
      'terminal', true,
      'reason', 'no_drivers_found',
      'dispatch_version', 3
    );
  END IF;

  IF v_wave = 0 THEN
    v_inner_km := 0;
    v_outer_km := v_max_radius_km;
    v_timeout := COALESCE(
      p_window_seconds,
      (v_cfg->>'my_drivers_window_seconds')::int,
      15
    );
    v_favorite_only := true;
    v_max_invites := 1;
  ELSIF v_wave = 1 THEN
    v_inner_km := 0;
    v_outer_km := COALESCE((v_cfg->>'wave1_radius_km')::numeric, 5);
    v_timeout := COALESCE(p_window_seconds, (v_cfg->>'wave1_timeout_seconds')::int, 10);
    IF v_surge THEN
      v_outer_km := COALESCE((v_cfg->>'surge_wave1_radius_km')::numeric, 8);
      v_timeout := COALESCE((v_cfg->>'surge_wave1_timeout_seconds')::int, 7);
    ELSIF v_night THEN
      v_outer_km := COALESCE((v_cfg->>'night_wave1_radius_km')::numeric, 8);
      v_timeout := COALESCE((v_cfg->>'night_wave1_timeout_seconds')::int, 15);
    END IF;

    SELECT COUNT(*) INTO v_wave1_count
    FROM public.driver_locations dl
    INNER JOIN public.drivers d ON d.id = dl.driver_id
    WHERE public.fn_dispatch_driver_eligible(
      d.id, v_ride, v_pickup, v_outer_km, v_cfg
    )
    AND ST_Distance(
      ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
      v_pickup
    ) / 1000.0 <= v_outer_km;

    IF v_wave1_count < COALESCE((v_cfg->>'low_density_wave1_threshold')::int, 3) THEN
      v_outer_km := COALESCE((v_cfg->>'wave2_radius_km')::numeric, 10);
      v_collapsed := true;
      v_state := v_state || jsonb_build_object('collapsed_waves_1_2', true);
    END IF;
  ELSIF v_wave = 2 THEN
    v_inner_km := COALESCE((v_cfg->>'wave1_radius_km')::numeric, 5);
    v_outer_km := COALESCE((v_cfg->>'wave2_radius_km')::numeric, 10);
    v_timeout := COALESCE(p_window_seconds, (v_cfg->>'wave2_timeout_seconds')::int, 12);
  ELSIF v_wave = 3 THEN
    v_inner_km := COALESCE((v_cfg->>'wave2_radius_km')::numeric, 10);
    v_outer_km := COALESCE((v_cfg->>'wave3_radius_km')::numeric, 20);
    v_timeout := COALESCE(p_window_seconds, (v_cfg->>'wave3_timeout_seconds')::int, 15);
  ELSE
    v_inner_km := COALESCE((v_cfg->>'wave3_radius_km')::numeric, 20);
    v_outer_km := v_max_radius_km;
    v_timeout := COALESCE(p_window_seconds, (v_cfg->>'wave4_timeout_seconds')::int, 20);
  END IF;

  WITH scored AS (
    SELECT
      dl.driver_id,
      ST_Distance(
        ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
        v_pickup
      ) / 1000.0 AS distance_km,
      (
        ST_Distance(
          ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
          v_pickup
        ) / 1000.0
      ) * v_eta_per_km AS eta_minutes,
      COALESCE(d.avg_rating, d.rating, 5.0) AS driver_rating,
      COALESCE(d.per_km_rate, 0) AS per_km_rate,
      d.full_name,
      CASE WHEN rfd.driver_id IS NOT NULL THEN true ELSE false END AS is_favorite,
      GREATEST(
        0,
        100 - (
          (
            ST_Distance(
              ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
              v_pickup
            ) / 1000.0
          ) / NULLIF(v_outer_km, 0)
        ) * 60
      ) AS distance_score,
      GREATEST(
        0,
        100 - (
          (
            ST_Distance(
              ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
              v_pickup
            ) / 1000.0
          ) * v_eta_per_km * 3
        )
      ) AS eta_score,
      GREATEST(
        0,
        (COALESCE(d.avg_rating, d.rating, 5.0) - 4.0) * 80
      ) AS rating_score,
      GREATEST(
        0,
        (v_tariff_ref - COALESCE(d.per_km_rate, 0)) * 20
      ) AS tariff_score
    FROM public.driver_locations dl
    INNER JOIN public.drivers d ON d.id = dl.driver_id
    LEFT JOIN public.rider_favorite_drivers rfd
      ON rfd.driver_id = d.id
      AND rfd.rider_identity_id = v_ride.rider_identity_id
    WHERE dl.updated_at > now() - make_interval(mins => v_gps_mins)
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND public.fn_dispatch_driver_eligible(d.id, v_ride, v_pickup, v_max_radius_km, v_cfg)
  ),
  ranked AS (
    SELECT
      s.*,
      round(
        (
          s.distance_score * v_w_dist
          + s.eta_score * v_w_eta
          + s.rating_score * v_w_rating
          + s.tariff_score * v_w_tariff
        )::numeric,
        2
      ) AS composite_score
    FROM scored s
    WHERE s.distance_km <= v_outer_km
      AND (v_inner_km <= 0 OR s.distance_km > v_inner_km)
      AND (
        NOT v_favorite_only
        OR s.is_favorite
      )
  )
  INSERT INTO public.ride_request_invites (
    ride_request_id,
    driver_id,
    batch_no,
    expires_at,
    status,
    composite_score,
    distance_km,
    eta_minutes
  )
  SELECT
    p_ride_request_id,
    r.driver_id,
    v_next_batch,
    now() + make_interval(secs => v_timeout),
    'pending',
    r.composite_score,
    round(r.distance_km::numeric, 2),
    round(r.eta_minutes::numeric, 1)
  FROM ranked r
  WHERE EXISTS (
    SELECT 1
    FROM public.driver_locations dl2
    WHERE dl2.driver_id = r.driver_id
      AND dl2.updated_at > now() - make_interval(mins => v_gps_mins)
  )
  ORDER BY r.composite_score DESC, r.distance_km ASC
  LIMIT v_max_invites;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  SELECT d.full_name INTO v_favorite_name
  FROM public.ride_request_invites i
  INNER JOIN public.drivers d ON d.id = i.driver_id
  WHERE i.ride_request_id = p_ride_request_id
    AND i.batch_no = v_next_batch
  ORDER BY i.composite_score DESC NULLS LAST
  LIMIT 1;

  v_state := v_state || jsonb_build_object(
    'last_wave', v_wave,
    'last_batch', v_next_batch,
    'surge', v_surge,
    'night', v_night,
    'collapsed_waves_1_2', v_collapsed,
    'wave_outer_km', v_outer_km,
    'wave_timeout_seconds', v_timeout,
    'favorite_name', v_favorite_name
  );

  UPDATE public.ride_requests rr
  SET dispatch_state = v_state,
      updated_at = now()
  WHERE rr.id = p_ride_request_id;

  v_t1 := clock_timestamp();
  v_duration_ms := EXTRACT(MILLISECONDS FROM (v_t1 - v_t0));

  v_metrics := jsonb_build_object(
    'wave', v_wave,
    'batch_no', v_next_batch,
    'invited', v_inserted,
    'inner_km', v_inner_km,
    'outer_km', v_outer_km,
    'timeout_seconds', v_timeout,
    'surge', v_surge,
    'night', v_night,
    'collapsed', v_collapsed,
    'dispatch_duration_ms', round(v_duration_ms)::int,
    'dispatch_version', 3
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'dispatch.wave_seeded',
    NULL,
    v_metrics,
    'system',
    'supabase_sda',
    p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'batch', v_next_batch,
    'wave', v_wave,
    'invited', v_inserted,
    'skip_metrics', v_metrics,
    'dispatch_version', 3,
    'dispatch_duration_ms', round(v_duration_ms)::int
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch (uuid, int, int) TO authenticated;

-- ---------------------------------------------------------------------------
-- Cron / worker: advance waves for all pending rides
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_advance_ride_matching_waves(
  p_limit int DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_result json;
  v_processed int := 0;
  v_seeded int := 0;
  v_terminal int := 0;
BEGIN
  FOR v_row IN
    SELECT r.id
    FROM public.ride_requests r
    WHERE r.status = 'pending'
      AND r.driver_id IS NULL
      AND r.pickup_coords IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.ride_request_invites i
        WHERE i.ride_request_id = r.id
          AND i.status = 'pending'
          AND i.expires_at > now()
      )
      AND (
        NOT EXISTS (
          SELECT 1 FROM public.ride_request_invites i2
          WHERE i2.ride_request_id = r.id
        )
        OR EXISTS (
          SELECT 1 FROM public.ride_request_invites i3
          WHERE i3.ride_request_id = r.id
            AND i3.status IN ('expired', 'wave_expired', 'superseded')
            AND NOT EXISTS (
              SELECT 1 FROM public.ride_request_invites i4
              WHERE i4.ride_request_id = r.id
                AND i4.status = 'accepted'
            )
        )
      )
    ORDER BY r.created_at ASC
    LIMIT greatest(1, least(p_limit, 500))
  LOOP
    v_processed := v_processed + 1;
    BEGIN
      v_result := public.fn_seed_ride_matching_batch(v_row.id, NULL, NULL);
      IF COALESCE((v_result->>'terminal')::boolean, false) THEN
        v_terminal := v_terminal + 1;
      ELSIF COALESCE((v_result->>'invited')::int, 0) > 0 THEN
        v_seeded := v_seeded + COALESCE((v_result->>'invited')::int, 0);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'processed_rides', v_processed,
    'invites_seeded', v_seeded,
    'terminal_no_drivers', v_terminal
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_advance_ride_matching_waves (int) TO authenticated;

-- ---------------------------------------------------------------------------
-- Rider-facing dispatch status (searching screen)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_rider_dispatch_status(
  p_ride_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_cfg jsonb;
  v_wave int := 1;
  v_state text := 'searching';
  v_batch int;
  v_pending int := 0;
  v_notified int := 0;
  v_closest_km numeric;
  v_fastest_eta numeric;
  v_expires_at timestamptz;
  v_timeout int := 10;
  v_outer_km numeric := 5;
  v_progress numeric := 0.15;
  v_favorite_name text;
  v_elapsed int := 0;
  v_total_timeout int := 57;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = rr.rider_identity_id
        AND ri.user_id = auth.uid()
    );

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  v_cfg := public.fn_dispatch_config();

  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    IF v_ride.status IN ('expired', 'cancelled', 'canceled', 'missed') THEN
      v_state := 'no_drivers';
    ELSIF v_ride.status IN ('accepted', 'assigned', 'driver_arrived', 'in_progress') THEN
      v_state := 'matched';
    ELSE
      v_state := 'terminal';
    END IF;
    RETURN jsonb_build_object(
      'ok', true,
      'state', v_state,
      'ride_status', v_ride.status,
      'dispatch_state', COALESCE(v_ride.dispatch_state, '{}'::jsonb)
    );
  END IF;

  v_favorite_name := v_ride.dispatch_state->>'favorite_name';
  v_wave := COALESCE((v_ride.dispatch_state->>'last_wave')::int, 0);
  v_outer_km := COALESCE((v_ride.dispatch_state->>'wave_outer_km')::numeric, 5);
  v_timeout := COALESCE((v_ride.dispatch_state->>'wave_timeout_seconds')::int, 10);

  SELECT COALESCE(MAX(i.batch_no), -1) INTO v_batch
  FROM public.ride_request_invites i
  WHERE i.ride_request_id = p_ride_request_id;

  IF v_batch < 0 THEN
    v_state := 'starting';
    v_wave := 0;
  ELSE
    SELECT
      COUNT(*) FILTER (WHERE i.status = 'pending' AND i.expires_at > now()),
      COUNT(*),
      MIN(i.distance_km),
      MIN(i.eta_minutes),
      MAX(i.expires_at) FILTER (WHERE i.status = 'pending' AND i.expires_at > now())
    INTO v_pending, v_notified, v_closest_km, v_fastest_eta, v_expires_at
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.batch_no = v_batch;

    IF v_pending > 0 THEN
      v_state := 'wave_active';
      IF v_expires_at IS NOT NULL THEN
        v_elapsed := greatest(
          0,
          v_timeout - EXTRACT(EPOCH FROM (v_expires_at - now()))::int
        );
      END IF;
    ELSE
      v_state := 'wave_expired';
    END IF;
  END IF;

  IF COALESCE(v_ride.dispatch_state->>'terminal', '') = 'no_drivers_found' THEN
    v_state := 'no_drivers';
  END IF;

  v_total_timeout :=
    COALESCE((v_cfg->>'wave1_timeout_seconds')::int, 10)
    + COALESCE((v_cfg->>'wave2_timeout_seconds')::int, 12)
    + COALESCE((v_cfg->>'wave3_timeout_seconds')::int, 15)
    + COALESCE((v_cfg->>'wave4_timeout_seconds')::int, 20);

  v_progress := LEAST(
    1.0,
    GREATEST(
      0.05,
      EXTRACT(EPOCH FROM (now() - v_ride.created_at)) / NULLIF(v_total_timeout, 0)
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'state', v_state,
    'wave', v_wave,
    'wave_outer_km', v_outer_km,
    'drivers_notified', COALESCE(v_notified, 0),
    'drivers_pending', COALESCE(v_pending, 0),
    'closest_km', v_closest_km,
    'fastest_eta_min', v_fastest_eta,
    'wave_timeout_seconds', v_timeout,
    'wave_elapsed_seconds', v_elapsed,
    'progress', round(v_progress::numeric, 3),
    'favorite_driver_name', v_favorite_name,
    'surge', COALESCE((v_ride.dispatch_state->>'surge')::boolean, false),
    'night', COALESCE((v_ride.dispatch_state->>'night')::boolean, false),
    'collapsed_waves', COALESCE((v_ride.dispatch_state->>'collapsed_waves_1_2')::boolean, false),
    'dispatch_state', COALESCE(v_ride.dispatch_state, '{}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_rider_dispatch_status (uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Supply snapshot for home map chip (zone counts)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_rider_supply_snapshot(
  p_lat double precision,
  p_lng double precision
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH cfg AS (
    SELECT public.fn_dispatch_config() AS c
  ),
  params AS (
    SELECT
      p_lat AS lat,
      p_lng AS lng,
      GREATEST(COALESCE((c->>'wave3_radius_km')::numeric, 20), 5) AS radius_km,
      GREATEST(COALESCE((c->>'gps_freshness_minutes')::int, 3), 1) AS max_age_minutes,
      COALESCE((c->>'eta_minutes_per_km')::numeric, 2.2) AS eta_per_km
    FROM cfg
  ),
  nearby AS (
    SELECT
      (
        6371.0 * 2.0 * asin(
          sqrt(
            power(sin(radians((dl.latitude - params.lat) / 2.0)), 2)
            + cos(radians(params.lat))
              * cos(radians(dl.latitude))
              * power(sin(radians((dl.longitude - params.lng) / 2.0)), 2)
          )
        )
      ) AS km,
      (
        6371.0 * 2.0 * asin(
          sqrt(
            power(sin(radians((dl.latitude - params.lat) / 2.0)), 2)
            + cos(radians(params.lat))
              * cos(radians(dl.latitude))
              * power(sin(radians((dl.longitude - params.lng) / 2.0)), 2)
          )
        )
      ) * params.eta_per_km AS eta_minutes
    FROM params
    JOIN public.driver_locations dl
      ON dl.updated_at >= now() - make_interval(mins => params.max_age_minutes)
    JOIN public.drivers d ON d.id = dl.driver_id
    WHERE d.status = 'available'
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
  )
  SELECT jsonb_build_object(
    'zone1_count', COUNT(*) FILTER (WHERE km <= 5),
    'zone2_count', COUNT(*) FILTER (WHERE km <= 10),
    'zone3_count', COUNT(*) FILTER (WHERE km <= 20),
    'total_count', COUNT(*) FILTER (WHERE km <= (SELECT radius_km FROM params)),
    'closest_km', MIN(km),
    'fastest_eta_min', MIN(eta_minutes)
  )
  FROM nearby, params
  WHERE km <= (SELECT radius_km FROM params);
$$;

GRANT EXECUTE ON FUNCTION public.fn_rider_supply_snapshot (double precision, double precision) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- Trigger: start SDA on insert (config-driven batch/window)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_ride_request_after_insert_matching ()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    BEGIN
      PERFORM public.fn_seed_ride_matching_batch(NEW.id, NULL, NULL);
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'fn_seed_ride_matching_batch skipped: %', SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- pg_cron: advance waves every minute (backup to client poll)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'heycaby_advance_matching_waves'
    ) THEN
      EXECUTE
        'SELECT cron.schedule(' ||
        quote_literal('heycaby_advance_matching_waves') || ', ' ||
        quote_literal('* * * * *') || ', ' ||
        quote_literal('SELECT public.fn_advance_ride_matching_waves(100);') ||
        ')';
    END IF;
  END IF;
END $$;
