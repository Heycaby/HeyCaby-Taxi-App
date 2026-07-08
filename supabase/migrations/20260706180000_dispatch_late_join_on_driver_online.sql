-- Late-join dispatch: when a driver goes online, re-check nearby active pending searches
-- and invite the driver without requiring the rider to cancel/rebook.

CREATE OR REPLACE FUNCTION public.fn_dispatch_late_join_config()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb;
BEGIN
  IF to_regprocedure('public.fn_dispatch_config()') IS NOT NULL THEN
    v_cfg := public.fn_dispatch_config();
  ELSE
    v_cfg := '{}'::jsonb;
  END IF;

  RETURN jsonb_build_object(
    'max_radius_km', GREATEST(
      COALESCE((v_cfg->>'wave4_radius_km')::numeric, 35),
      COALESCE((v_cfg->>'night_max_radius_km')::numeric, 50)
    ),
    'gps_freshness_minutes', COALESCE((v_cfg->>'gps_freshness_minutes')::int, 3),
    'invite_window_seconds', COALESCE(
      (v_cfg->>'min_driver_accept_window_seconds')::int,
      (v_cfg->>'wave1_timeout_seconds')::int,
      30
    ),
    'favorites_window_seconds', COALESCE(
      (v_cfg->>'my_drivers_window_seconds')::int,
      15
    ),
    'has_sda_eligible',
      to_regprocedure(
        'public.fn_dispatch_driver_eligible(uuid,public.ride_requests,geography,numeric,jsonb)'
      ) IS NOT NULL
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
     AND COALESCE(v_ride.favorites_first, false)
     AND NOT EXISTS (
       SELECT 1
       FROM public.rider_favorite_drivers rfd
       WHERE rfd.driver_id = p_driver_id
         AND rfd.rider_identity_id = v_ride.rider_identity_id
     )
     AND v_ride.created_at > now() - make_interval(secs => v_favorites_window_seconds) THEN
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

CREATE OR REPLACE FUNCTION public.fn_dispatch_recheck_pending_on_driver_online(
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dl public.driver_locations%ROWTYPE;
  v_cfg jsonb;
  v_max_radius_km numeric;
  v_gps_mins int;
  v_ride_id uuid;
  v_result jsonb;
  v_invited int := 0;
  v_skipped int := 0;
  v_checked int := 0;
  v_outcomes jsonb := '[]'::jsonb;
BEGIN
  v_cfg := public.fn_dispatch_late_join_config();
  v_max_radius_km := (v_cfg->>'max_radius_km')::numeric;
  v_gps_mins := (v_cfg->>'gps_freshness_minutes')::int;

  SELECT * INTO v_dl
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
  ORDER BY dl.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_dl.driver_id IS NULL
     OR v_dl.latitude IS NULL
     OR v_dl.longitude IS NULL
     OR v_dl.updated_at <= now() - make_interval(mins => v_gps_mins) THEN
    RETURN jsonb_build_object(
      'ok', true,
      'rides_found', 0,
      'invited', 0,
      'skipped', 0,
      'driver_gps_stale', true
    );
  END IF;

  FOR v_ride_id IN
    SELECT rr.id
    FROM public.ride_requests rr
    WHERE rr.status = 'pending'
      AND rr.driver_id IS NULL
      AND rr.pickup_coords IS NOT NULL
      AND (rr.expires_at IS NULL OR rr.expires_at > now())
      AND ST_DWithin(
        rr.pickup_coords,
        ST_SetSRID(ST_MakePoint(v_dl.longitude, v_dl.latitude), 4326)::geography,
        v_max_radius_km * 1000.0
      )
      AND NOT (
        rr.booking_mode IS NOT DISTINCT FROM 'scheduled'
        AND rr.scheduled_pickup_at IS NOT NULL
        AND rr.scheduled_pickup_at - make_interval(
          mins => public.fn_scheduled_matching_lead_minutes()
        ) > now()
      )
    ORDER BY ST_Distance(
      rr.pickup_coords,
      ST_SetSRID(ST_MakePoint(v_dl.longitude, v_dl.latitude), 4326)::geography
    ) ASC
    LIMIT 15
  LOOP
    v_checked := v_checked + 1;
    v_result := public.fn_dispatch_try_late_join_invite(v_ride_id, p_driver_id);

  PERFORM public.fn_ride_audit_append(
    v_ride_id,
    'dispatch.pending_search_rechecked_on_driver_online',
    p_driver_id,
    jsonb_build_object(
      'ride_request_id', v_ride_id,
      'outcome', v_result
    ),
    'system',
    'supabase_dispatch',
    v_ride_id
  );

    IF COALESCE((v_result->>'invited')::boolean, false) THEN
      v_invited := v_invited + 1;
    ELSE
      v_skipped := v_skipped + 1;
    END IF;

    v_outcomes := v_outcomes || jsonb_build_array(v_result);
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'rides_found', v_checked,
    'invited', v_invited,
    'skipped', v_skipped,
    'outcomes', v_outcomes
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_set_status(
  p_status text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_user_id uuid := auth.uid();
  v_d public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_billing jsonb;
  v_flags jsonb;
  v_skip_gates boolean := false;
  v_status text := lower(trim(COALESCE(p_status, '')));
  v_has_fresh_gps boolean := false;
  v_has_tariff boolean := false;
  v_late_join jsonb;
BEGIN
  IF v_status NOT IN ('available', 'offline', 'on_break') THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'invalid_status',
      'message', 'Invalid status'
    );
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_user_id
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'not_a_driver',
      'message', 'Driver profile not found'
    );
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;

  v_flags := public.fn_app_config_jsonb('feature_flags');
  v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

  IF v_status = 'available' THEN
    v_readiness := public.fn_driver_readiness_eval(v_driver_id);
    IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'status', 'offline',
        'blocked_reason', 'missing_docs',
        'message', COALESCE(v_readiness->>'status_message', 'Compliance incomplete'),
        'readiness', v_readiness
      );
    END IF;

    IF NOT v_skip_gates AND NOT public.fn_driver_is_review_account(v_user_id) THEN
      v_has_fresh_gps := (p_lat IS NOT NULL AND p_lng IS NOT NULL)
        OR EXISTS (
          SELECT 1 FROM public.driver_locations dl
          WHERE dl.driver_id = v_driver_id
            AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
            AND dl.updated_at > now() - interval '5 minutes'
        );
      IF NOT v_has_fresh_gps THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'missing_location',
          'message', 'Enable location to go online',
          'redirect', '/driver/location'
        );
      END IF;

      v_has_tariff := EXISTS (
        SELECT 1 FROM public.driver_rate_profiles rp
        WHERE rp.driver_id = v_driver_id AND rp.is_active = true
      );
      IF NOT v_has_tariff THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'missing_tariff',
          'message', 'Set your first tariff before going online',
          'redirect', '/driver/tariffs'
        );
      END IF;

      PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);
      v_billing := public.fn_driver_can_accept_rides(v_driver_id);
      IF COALESCE((v_billing->>'allowed')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object(
          'status', 'offline',
          'blocked_reason', 'payment_required',
          'message', COALESCE(v_billing->>'reason', 'Platform fee payment required'),
          'redirect', '/driver/billing'
        );
      END IF;
    END IF;
  END IF;

  UPDATE public.drivers
  SET status = v_status::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = v_driver_id;

  IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    INSERT INTO public.driver_locations (
      user_id, driver_id, latitude, longitude, country_code, updated_at
    )
    VALUES (
      v_user_id, v_driver_id, p_lat, p_lng,
      COALESCE(v_d.country_code, 'NL'), timezone('utc', now())
    )
    ON CONFLICT (user_id) DO UPDATE
    SET driver_id = EXCLUDED.driver_id,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        country_code = EXCLUDED.country_code,
        updated_at = EXCLUDED.updated_at;
  END IF;

  IF v_status = 'available' THEN
    v_late_join := public.fn_dispatch_recheck_pending_on_driver_online(v_driver_id);
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'message', CASE
      WHEN v_status = 'available' THEN 'Online'
      WHEN v_status = 'on_break' THEN 'On break'
      ELSE 'Offline'
    END,
    'late_join_dispatch', v_late_join
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_dispatch_late_join_config() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dispatch_try_late_join_invite(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dispatch_recheck_pending_on_driver_online(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_dispatch_late_join_config() TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_dispatch_try_late_join_invite(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_dispatch_recheck_pending_on_driver_online(uuid) TO service_role;

COMMENT ON FUNCTION public.fn_dispatch_recheck_pending_on_driver_online(uuid) IS
  'On driver go-online: find nearby pending ride searches and invite this driver when eligible (late-join dispatch).';
