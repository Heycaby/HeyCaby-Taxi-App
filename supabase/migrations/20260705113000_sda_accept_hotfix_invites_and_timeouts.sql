-- Hotfix: restore accept flow after SDA v1.
-- 1) Dispatch eligibility aligned with pre-SDA matching (go-online already gates photos/compliance).
-- 2) Wave timeouts >= driver opportunity window (30s).
-- 3) Accept allows wave_expired invites within driver UI grace window.

UPDATE public.app_config
SET value = COALESCE(value::jsonb, '{}'::jsonb) || jsonb_build_object(
  'wave1_timeout_seconds', 30,
  'wave2_timeout_seconds', 30,
  'wave3_timeout_seconds', 35,
  'wave4_timeout_seconds', 40,
  'my_drivers_window_seconds', 30,
  'surge_wave1_timeout_seconds', 25,
  'night_wave1_timeout_seconds', 35,
  'min_driver_accept_window_seconds', 30
)
WHERE key = 'dispatch_config';

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
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_accept_grace := COALESCE(
    (public.fn_dispatch_config()->>'min_driver_accept_window_seconds')::int,
    30
  );

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
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
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) = false THEN
    PERFORM public.fn_billing_audit_append(
      v_driver_id, 'billing.accept_blocked', p_ride_request_id,
      jsonb_build_object(
        'reason', v_billing->>'reason',
        'status', v_billing->>'status',
        'outstanding_cents', v_billing->>'outstanding_cents',
        'limit_cents', v_billing->>'limit_cents',
        'billing_enforcement', v_billing->>'billing_enforcement'
      ),
      p_ride_request_id
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.driver_rejected_billing', v_driver_id,
      jsonb_build_object(
        'reason', v_billing->>'reason',
        'status', v_billing->>'status',
        'outstanding_cents', v_billing->>'outstanding_cents',
        'limit_cents', v_billing->>'limit_cents'
      ),
      'driver', 'supabase_trigger', p_ride_request_id
    );
    RETURN json_build_object(
      'ok', false, 'error', 'billing_locked',
      'message', COALESCE(v_billing->>'reason', 'Outstanding platform fees exceed market limit.')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status IN ('pending', 'wave_expired')
      AND i.expires_at > now() - make_interval(secs => v_accept_grace)
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'no_valid_invite');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id AND rp.is_active = true
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'missing_tariff');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_locations dl
    WHERE dl.driver_id = v_driver_id
      AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - interval '3 minutes'
  ) THEN
    RETURN json_build_object('ok', false, 'error', 'stale_location');
  END IF;

  IF NOT public.fn_payment_compatible(v_driver_id, v_ride.payment_methods) THEN
    RETURN json_build_object('ok', false, 'error', 'payment_incompatible');
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
    RETURN json_build_object('ok', false, 'error', 'race_lost');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id <> v_driver_id
    AND i.status IN ('pending', 'wave_expired');

  UPDATE public.ride_request_invites i
  SET status = 'accepted'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status IN ('pending', 'wave_expired');

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
    COALESCE(v_d.full_name, 'Your driver') || ' is on the way'
      || CASE
           WHEN COALESCE(v_d.vehicle_make, '') <> ''
             THEN ' in a ' || v_d.vehicle_make || ' ' || COALESCE(v_d.vehicle_model, '')
           ELSE ''
         END || '.',
    jsonb_build_object(
      'type', 'driver_found',
      'ride_request_id', p_ride_request_id,
      'driver_name', v_d.full_name,
      'vehicle_make', v_d.vehicle_make,
      'vehicle_model', v_d.vehicle_model,
      'vehicle_plate', v_d.vehicle_plate,
      'conversation_id', v_conversation_id
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.accepted', v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver', 'rpc', p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;
