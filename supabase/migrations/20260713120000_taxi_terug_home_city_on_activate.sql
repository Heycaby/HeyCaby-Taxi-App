-- Persist home profile when activating Taxi Terug with intent home.

CREATE OR REPLACE FUNCTION public.fn_driver_return_mode_activate(
  p_destination_label text DEFAULT NULL,
  p_destination_zone_id uuid DEFAULT NULL,
  p_destination_lat double precision DEFAULT NULL,
  p_destination_lng double precision DEFAULT NULL,
  p_pickup_radius_km numeric DEFAULT NULL,
  p_return_discount_pct numeric DEFAULT NULL,
  p_intent_type text DEFAULT NULL,
  p_departure_time timestamptz DEFAULT NULL,
  p_destination_radius_km numeric DEFAULT NULL
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
  v_intent_type text;
  v_dest_radius numeric;
  v_max_delay_hours int;
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

  v_intent_type := coalesce(
    nullif(trim(p_intent_type), ''),
    'post_ride_return'
  );
  IF v_intent_type NOT IN (
    'home', 'airport', 'city', 'custom',
    'post_ride_return', 'planned_direction'
  ) THEN
    v_intent_type := 'post_ride_return';
  END IF;

  v_max_delay_hours := COALESCE((v_cfg->>'max_departure_delay_hours')::int, 12);
  IF p_departure_time IS NOT NULL
     AND p_departure_time > now() + make_interval(hours => v_max_delay_hours) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'departure_time_too_far');
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
  ), 0), 50);
  v_dest_radius := least(greatest(coalesce(
    p_destination_radius_km,
    (v_cfg->>'default_destination_radius_km')::numeric,
    5
  ), 1), 50);

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
    return_mode_intent_type = v_intent_type,
    return_mode_departure_time = p_departure_time,
    return_mode_destination_radius_km = v_dest_radius,
    pickup_distance_max_km = v_pickup_radius,
    home_city = CASE
      WHEN v_intent_type = 'home' THEN v_destination_label
      ELSE d.home_city
    END,
    heading_home_zone_id = CASE
      WHEN v_intent_type = 'home' AND p_destination_zone_id IS NOT NULL
        THEN p_destination_zone_id
      ELSE d.heading_home_zone_id
    END,
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
      'destination_changed', v_destination_changed,
      'intent_type', v_intent_type,
      'departure_time', p_departure_time,
      'destination_radius_km', v_dest_radius
    )
  );

  RETURN public.fn_driver_return_mode_status();
END;
$$;
