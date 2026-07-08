-- Marketplace driver audience dispatch: favorites_only on ride_requests.
-- everyone: favorites_first=false, favorites_only=false → radius waves, all eligible drivers
-- my drivers first: wave 0 favorites-only window, then radius waves for everyone
-- my drivers only: every wave filters to rider_favorite_drivers (radius still applies)

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS favorites_only boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.ride_requests.favorites_only IS
  'When true, dispatch only invites active rider_favorite_drivers within wave radius.';

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
    AND rfd.is_active = true
  WHERE d.status = 'available'
    AND (
      NOT COALESCE(v_ride.favorites_only, false)
      OR rfd.driver_id IS NOT NULL
    )
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
      WHEN COALESCE(v_ride.favorites_first, false)
           AND NOT COALESCE(v_ride.favorites_only, false) THEN
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
  v_preferred_timeout int;
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

  -- Direct dispatch: rider picked a specific driver (preferred_driver_id).
  IF v_ride.preferred_driver_id IS NOT NULL THEN
    v_preferred_timeout := COALESCE(
      p_window_seconds,
      (v_cfg->>'my_drivers_window_seconds')::int,
      (v_cfg->>'min_driver_accept_window_seconds')::int,
      30
    );
    v_max_radius_km := GREATEST(
      COALESCE((v_cfg->>'wave4_radius_km')::numeric, 35),
      COALESCE((v_cfg->>'night_max_radius_km')::numeric, 50)
    );

    IF public.fn_dispatch_driver_eligible(
      v_ride.preferred_driver_id, v_ride, v_pickup, v_max_radius_km, v_cfg
    ) THEN
      INSERT INTO public.ride_request_invites (
        ride_request_id, driver_id, batch_no, invited_at, expires_at, status
      )
      VALUES (
        p_ride_request_id,
        v_ride.preferred_driver_id,
        0,
        now(),
        now() + make_interval(secs => v_preferred_timeout),
        'pending'
      )
      ON CONFLICT (ride_request_id, driver_id) DO UPDATE
        SET status = 'pending',
            expires_at = EXCLUDED.expires_at,
            invited_at = now(),
            batch_no = 0
      WHERE public.ride_request_invites.status <> 'accepted';

      GET DIAGNOSTICS v_inserted = ROW_COUNT;

      UPDATE public.ride_requests rr
      SET dispatch_state = COALESCE(v_ride.dispatch_state, '{}'::jsonb) || jsonb_build_object(
            'last_wave', 0,
            'last_batch', 0,
            'preferred_driver', true,
            'wave_timeout_seconds', v_preferred_timeout
          ),
          updated_at = now()
      WHERE rr.id = p_ride_request_id;

      RETURN json_build_object(
        'ok', true,
        'wave', 0,
        'batch_no', 0,
        'invited', GREATEST(v_inserted, 1),
        'preferred_driver', true,
        'timeout_seconds', v_preferred_timeout,
        'dispatch_version', 3
      );
    END IF;
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
        AND NOT COALESCE(v_ride.favorites_only, false)
        AND EXISTS (
          SELECT 1
          FROM public.rider_favorite_drivers rfd
          INNER JOIN public.drivers d ON d.id = rfd.driver_id
          WHERE rfd.rider_identity_id = v_ride.rider_identity_id
            AND rfd.is_active = true
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

  IF COALESCE(v_ride.favorites_only, false) THEN
    v_favorite_only := true;
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
      AND rfd.is_active = true
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
    'favorite_name', v_favorite_name,
    'favorites_only', COALESCE(v_ride.favorites_only, false),
    'favorites_first', COALESCE(v_ride.favorites_first, false)
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
    'dispatch_version', 3,
    'favorites_only', COALESCE(v_ride.favorites_only, false),
    'favorites_first', COALESCE(v_ride.favorites_first, false)
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
    'wave', v_wave,
    'batch_no', v_next_batch,
    'invited', v_inserted,
    'metrics', v_metrics,
    'dispatch_version', 3
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_dispatch_try_late_join_invite(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_d public.drivers%ROWTYPE;
  v_dl public.driver_locations%ROWTYPE;
  v_cfg jsonb;
  v_max_radius_km numeric;
  v_gps_mins int;
  v_window_seconds int;
  v_favorites_window_seconds int;
  v_distance_km numeric;
  v_batch_no int;
  v_skip_reason text;
  v_scheduled_lead_minutes int;
  v_matching_starts_at timestamptz;
  v_has_sda boolean;
  v_dispatch_cfg jsonb;
BEGIN
  v_dispatch_cfg := public.fn_dispatch_late_join_config();
  v_max_radius_km := (v_dispatch_cfg->>'max_radius_km')::numeric;
  v_gps_mins := (v_dispatch_cfg->>'gps_freshness_minutes')::int;
  v_window_seconds := (v_dispatch_cfg->>'invite_window_seconds')::int;
  v_favorites_window_seconds := (v_dispatch_cfg->>'favorites_window_seconds')::int;
  v_has_sda := COALESCE((v_dispatch_cfg->>'has_sda_eligible')::boolean, false);

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND THEN
    v_skip_reason := 'ride_not_pending';
  ELSIF v_ride.status IS DISTINCT FROM 'pending' OR v_ride.driver_id IS NOT NULL THEN
    v_skip_reason := 'ride_not_pending';
  ELSIF v_ride.expires_at IS NOT NULL AND v_ride.expires_at <= now() THEN
    v_skip_reason := 'ride_expired';
  ELSIF v_ride.pickup_coords IS NULL THEN
    v_skip_reason := 'ride_not_pending';
  ELSIF v_ride.booking_mode IS NOT DISTINCT FROM 'scheduled'
        AND v_ride.scheduled_pickup_at IS NOT NULL THEN
    v_scheduled_lead_minutes := public.fn_scheduled_matching_lead_minutes();
    v_matching_starts_at :=
      v_ride.scheduled_pickup_at - make_interval(mins => v_scheduled_lead_minutes);
    IF v_matching_starts_at > now() THEN
      v_skip_reason := 'driver_not_eligible';
    END IF;
  END IF;

  IF v_skip_reason IS NULL AND EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = p_driver_id
  ) THEN
    v_skip_reason := 'already_invited';
  END IF;

  IF v_skip_reason IS NULL
     AND v_ride.preferred_driver_id IS NOT NULL
     AND v_ride.preferred_driver_id IS DISTINCT FROM p_driver_id THEN
    v_skip_reason := 'driver_not_eligible';
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF v_skip_reason IS NULL AND NOT FOUND THEN
    v_skip_reason := 'driver_not_eligible';
  END IF;

  IF v_skip_reason IS NULL
     AND (
       COALESCE(v_ride.favorites_only, false)
       OR (
         COALESCE(v_ride.favorites_first, false)
         AND v_ride.created_at > now() - make_interval(secs => v_favorites_window_seconds)
       )
     )
     AND NOT EXISTS (
       SELECT 1
       FROM public.rider_favorite_drivers rfd
       WHERE rfd.driver_id = p_driver_id
         AND rfd.rider_identity_id = v_ride.rider_identity_id
         AND rfd.is_active = true
     ) THEN
    v_skip_reason := 'driver_not_eligible';
  END IF;

  SELECT * INTO v_dl
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
  ORDER BY dl.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_skip_reason IS NULL THEN
    IF v_dl.driver_id IS NULL
       OR v_dl.latitude IS NULL
       OR v_dl.longitude IS NULL
       OR v_dl.updated_at <= now() - make_interval(mins => v_gps_mins) THEN
      v_skip_reason := 'gps_stale';
    END IF;
  END IF;

  IF v_skip_reason IS NULL AND v_d.status IS DISTINCT FROM 'available' THEN
    v_skip_reason := 'driver_not_eligible';
  END IF;

  IF v_skip_reason IS NULL
     AND COALESCE((public.fn_driver_can_accept_rides(p_driver_id)->>'allowed')::boolean, false) = false THEN
    v_skip_reason := 'driver_not_eligible';
  END IF;

  IF v_skip_reason IS NULL
     AND NOT public.fn_payment_compatible(p_driver_id, v_ride.payment_methods) THEN
    v_skip_reason := 'payment_mismatch';
  END IF;

  IF v_skip_reason IS NULL AND NOT (
    (
      (
        v_ride.vehicle_categories IS NULL
        OR cardinality(v_ride.vehicle_categories) IS NULL
        OR cardinality(v_ride.vehicle_categories) = 0
      )
      AND (
        v_ride.vehicle_category IS NULL
        OR trim(both from v_ride.vehicle_category::text) = ''
        OR lower(trim(both from v_d.vehicle_category::text)) = lower(trim(both from v_ride.vehicle_category::text))
      )
    )
    OR (
      v_ride.vehicle_categories IS NOT NULL
      AND cardinality(v_ride.vehicle_categories) > 0
      AND lower(trim(both from v_d.vehicle_category::text)) = ANY (
        SELECT lower(trim(both from c))
        FROM unnest(v_ride.vehicle_categories) AS c
      )
    )
  ) THEN
    v_skip_reason := 'vehicle_mismatch';
  END IF;

  IF v_skip_reason IS NULL
     AND COALESCE(v_ride.pet_friendly, false)
     AND NOT COALESCE(v_d.accepts_pets, false) THEN
    v_skip_reason := 'vehicle_mismatch';
  END IF;

  IF v_skip_reason IS NULL AND EXISTS (
    SELECT 1
    FROM public.ride_request_invites x
    WHERE x.driver_id = p_driver_id
      AND x.status = 'pending'
      AND x.expires_at > now()
      AND x.ride_request_id <> p_ride_request_id
  ) THEN
    v_skip_reason := 'driver_not_eligible';
  END IF;

  IF v_skip_reason IS NULL THEN
    v_distance_km := ST_Distance(
      ST_SetSRID(ST_MakePoint(v_dl.longitude, v_dl.latitude), 4326)::geography,
      v_ride.pickup_coords
    ) / 1000.0;

    IF v_distance_km > v_max_radius_km THEN
      v_skip_reason := 'too_far';
    END IF;
  END IF;

  IF v_skip_reason IS NULL AND v_has_sda THEN
    v_cfg := public.fn_dispatch_config();
    IF NOT public.fn_dispatch_driver_eligible(
      p_driver_id, v_ride, v_ride.pickup_coords, v_max_radius_km, v_cfg
    ) THEN
      v_skip_reason := 'driver_not_eligible';
    END IF;
  END IF;

  IF v_skip_reason IS NOT NULL THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id,
      'dispatch.late_join_driver_skipped',
      p_driver_id,
      jsonb_build_object(
        'reason', v_skip_reason,
        'distance_km', v_distance_km
      ),
      'system',
      'supabase_dispatch',
      p_ride_request_id
    );

    RETURN jsonb_build_object(
      'invited', false,
      'skipped', true,
      'reason', v_skip_reason,
      'ride_request_id', p_ride_request_id,
      'driver_id', p_driver_id
    );
  END IF;

  SELECT COALESCE(
    (
      SELECT MAX(i.batch_no)
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = p_ride_request_id
        AND i.status = 'pending'
        AND i.expires_at > now()
    ),
    (
      SELECT COALESCE(MAX(i.batch_no), 0) + 1
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = p_ride_request_id
    ),
    1
  ) INTO v_batch_no;

  INSERT INTO public.ride_request_invites (
    ride_request_id,
    driver_id,
    batch_no,
    invited_at,
    expires_at,
    status
  )
  VALUES (
    p_ride_request_id,
    p_driver_id,
    v_batch_no,
    now(),
    now() + make_interval(secs => v_window_seconds),
    'pending'
  )
  ON CONFLICT (ride_request_id, driver_id) DO UPDATE
    SET status = 'pending',
        expires_at = EXCLUDED.expires_at,
        invited_at = now(),
        batch_no = EXCLUDED.batch_no
  WHERE public.ride_request_invites.status <> 'accepted';

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'dispatch.late_join_driver_invited',
    p_driver_id,
    jsonb_build_object(
      'batch_no', v_batch_no,
      'distance_km', round(v_distance_km::numeric, 2),
      'expires_in_seconds', v_window_seconds,
      'late_join', true
    ),
    'system',
    'supabase_dispatch',
    p_ride_request_id
  );

  RETURN jsonb_build_object(
    'invited', true,
    'skipped', false,
    'ride_request_id', p_ride_request_id,
    'driver_id', p_driver_id,
    'batch_no', v_batch_no,
    'distance_km', round(v_distance_km::numeric, 2)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch_legacy (uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch (uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dispatch_try_late_join_invite (uuid, uuid) TO authenticated;
