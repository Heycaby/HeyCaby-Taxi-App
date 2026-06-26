-- Communication subsystem: rider ping opened RPC + platform_health.communication

CREATE OR REPLACE FUNCTION public.fn_rider_ping_mark_opened(
  p_ride_id uuid,
  p_ping_kind text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_kind text;
  v_event text;
BEGIN
  IF v_uid IS NULL OR p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  v_kind := lower(trim(replace(COALESCE(p_ping_kind, ''), '-', '_')));
  IF v_kind = 'nearby' THEN
    v_kind := 'on_my_way';
  END IF;
  IF v_kind = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_kind');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
    WHERE rr.id = p_ride_id
      AND ri.user_id = v_uid
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  v_event := 'driver.ping_' || v_kind || '.opened';

  PERFORM public.fn_ride_audit_append(
    p_ride_id,
    v_event,
    v_uid,
    jsonb_build_object(
      'delivery_state', 'opened',
      'ping_kind', v_kind
    )
  );

  RETURN jsonb_build_object('ok', true, 'event', v_event);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_ping_mark_opened(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_ping_mark_opened(uuid, text) TO authenticated;

-- Extend platform health with communication observability
CREATE OR REPLACE FUNCTION public.fn_driver_platform_health(
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_d public.drivers%ROWTYPE;
  v_billing jsonb;
  v_summary jsonb;
  v_verified boolean;
  v_docs boolean;
  v_vehicle boolean;
  v_online boolean;
  v_dispatch_eligible boolean;
  v_session public.driver_sessions%ROWTYPE;
  v_layers_aligned boolean;
  v_active_ride_id uuid;
  v_last_ping record;
  v_last_delivered record;
  v_push_ok boolean;
  v_cooldown_sec int := 0;
BEGIN
  IF p_driver_id IS NOT NULL THEN
    IF auth.uid() IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
       AND NOT EXISTS (
         SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
       )
    THEN
      RETURN jsonb_build_object('allowed', false, 'error', 'forbidden');
    END IF;
    v_driver_id := p_driver_id;
  ELSE
    SELECT d.id INTO v_driver_id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'driver_not_found');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  v_summary := public.fn_driver_billing_summary(v_driver_id);

  v_verified := COALESCE(v_d.profile_status = 'verified', false)
    OR COALESCE(v_d.is_verified_badge, false);
  v_docs := COALESCE(v_d.chauffeurspas_verified, false)
    AND COALESCE(v_d.rijbewijs_verified, false)
    AND COALESCE(v_d.taxi_insurance_verified, false);
  v_vehicle := COALESCE(v_d.vehicle_verified, false)
    OR COALESCE(v_d.vehicle_photos_approved, false);
  v_online := v_d.status = 'available';

  v_dispatch_eligible :=
    COALESCE((v_billing->>'allowed')::boolean, false)
    AND v_online
    AND COALESCE(v_d.compliance_status, '') IS DISTINCT FROM 'suspended'
    AND COALESCE(v_d.min_profile_requirements_met, false);

  SELECT * INTO v_session
  FROM public.driver_sessions s
  WHERE s.driver_id = v_driver_id AND s.is_authoritative = true AND s.ended_at IS NULL
  ORDER BY s.created_at DESC
  LIMIT 1;

  v_layers_aligned := (
    v_session.id IS NULL
    OR v_d.status::text IS NOT DISTINCT FROM v_session.operational_state
  );

  SELECT rr.id INTO v_active_ride_id
  FROM public.ride_requests rr
  WHERE rr.driver_id = v_driver_id
    AND rr.status::text IN (
      'accepted', 'driver_arrived', 'driver_en_route', 'in_progress', 'assigned'
    )
  ORDER BY rr.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_active_ride_id IS NOT NULL THEN
    SELECT ral.event, ral.metadata, ral.occurred_at
    INTO v_last_ping
    FROM public.ride_audit_log ral
    WHERE ral.ride_id = v_active_ride_id
      AND ral.event LIKE 'driver.ping_%'
      AND ral.event NOT LIKE '%.delivered'
      AND ral.event NOT LIKE '%.opened'
    ORDER BY ral.occurred_at DESC
    LIMIT 1;

    SELECT ral.event, ral.occurred_at
    INTO v_last_delivered
    FROM public.ride_audit_log ral
    WHERE ral.ride_id = v_active_ride_id
      AND ral.event LIKE 'driver.ping_%.delivered'
    ORDER BY ral.occurred_at DESC
    LIMIT 1;

    IF v_last_ping.occurred_at IS NOT NULL
       AND v_last_ping.occurred_at > timezone('utc', now()) - interval '30 seconds'
    THEN
      v_cooldown_sec := GREATEST(
        0,
        30 - EXTRACT(EPOCH FROM (timezone('utc', now()) - v_last_ping.occurred_at))::int
      );
    END IF;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.push_devices pd
    WHERE pd.driver_id = v_driver_id
      AND pd.fcm_token IS NOT NULL
      AND length(trim(pd.fcm_token)) > 10
  ) INTO v_push_ok;

  RETURN jsonb_build_object(
    'allowed', v_dispatch_eligible,
    'billing', jsonb_build_object(
      'status', v_summary->>'status',
      'outstanding', (v_summary->>'outstanding')::bigint,
      'limit', (v_summary->>'limit')::bigint,
      'remaining', (v_summary->>'remaining')::bigint,
      'currency', v_summary->>'currency',
      'can_accept_rides', (v_billing->>'allowed')::boolean
    ),
    'driver', jsonb_build_object(
      'verified', v_verified,
      'documents_valid', v_docs,
      'vehicle_approved', v_vehicle,
      'is_online', v_online,
      'compliance_status', v_d.compliance_status,
      'profile_status', v_d.profile_status,
      'operational_status', v_d.status::text
    ),
    'connectivity', jsonb_build_object(
      'm14_enabled', public.fn_connectivity_m14_enabled(v_driver_id),
      'session_id', v_session.id,
      'transport', COALESCE(v_session.transport_state, 'disconnected'),
      'presence', COALESCE(v_session.presence_state, 'unknown'),
      'operational', COALESCE(v_session.operational_state, 'offline'),
      'last_heartbeat_at', v_session.last_heartbeat_at,
      'last_realtime_at', v_session.last_realtime_at,
      'legacy_status', v_d.status::text,
      'layers_aligned', v_layers_aligned,
      'state_machine_version', COALESCE(v_session.state_machine_version, 1)
    ),
    'communication', jsonb_build_object(
      'chat_available', v_active_ride_id IS NOT NULL,
      'push_available', v_push_ok,
      'active_ride_id', v_active_ride_id,
      'last_ping_event', v_last_ping.event,
      'last_ping_at', v_last_ping.occurred_at,
      'last_ping_automatic', COALESCE((v_last_ping.metadata->>'automatic')::boolean, false),
      'last_ping_delivered', v_last_delivered.event IS NOT NULL,
      'last_ping_delivered_at', v_last_delivered.occurred_at,
      'cooldown_remaining_sec', v_cooldown_sec
    ),
    'dispatch', jsonb_build_object(
      'eligible', v_dispatch_eligible
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_platform_health(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_health(uuid) TO authenticated, service_role;
