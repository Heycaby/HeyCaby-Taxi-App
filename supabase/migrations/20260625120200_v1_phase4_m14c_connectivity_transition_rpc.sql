-- M14C — fn_driver_connectivity_transition (single writer). REPO ONLY.
-- Does NOT modify dispatch, billing, accept, or ride matching.

CREATE OR REPLACE FUNCTION public.fn_connectivity_m14_enabled(p_driver_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_country text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN true;
  END IF;
  SELECT COALESCE(d.country_code, 'NL') INTO v_country
  FROM public.drivers d WHERE d.id = p_driver_id;
  RETURN COALESCE(
    (public.fn_get_market_config('connectivity_m14_enabled', v_country, NULL, NULL) #>> '{}')::boolean,
    false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_connectivity_operational_target(
  p_from text,
  p_event_type text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_event_type = 'connectivity.operational.go_available' AND p_from IN ('offline', 'paused') THEN 'available'
    WHEN p_event_type = 'connectivity.operational.go_offline' AND p_from IN ('available', 'paused') THEN 'offline'
    WHEN p_event_type = 'connectivity.operational.go_paused' AND p_from = 'available' THEN 'paused'
    WHEN p_event_type = 'connectivity.operational.ride_accepted' AND p_from = 'available' THEN 'busy'
    WHEN p_event_type = 'connectivity.operational.trip_completed' AND p_from = 'busy' THEN 'available'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.fn_connectivity_transport_target(
  p_from text,
  p_event_type text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_event_type = 'connectivity.transport.connected' AND p_from = 'disconnected' THEN 'connected'
    WHEN p_event_type = 'connectivity.transport.disconnected' AND p_from = 'connected' THEN 'disconnected'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_connectivity_transition(p_event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_session public.driver_sessions%ROWTYPE;
  v_event_id uuid;
  v_event_version integer;
  v_sm_version integer;
  v_event_type text;
  v_layer text;
  v_device_id text;
  v_metadata jsonb;
  v_from_state jsonb;
  v_to_state jsonb;
  v_target_transport text;
  v_target_presence text;
  v_target_operational text;
  v_existing jsonb;
  v_country text;
BEGIN
  v_event_type := p_event->>'event_type';
  v_event_id := COALESCE((p_event->>'event_id')::uuid, gen_random_uuid());
  v_event_version := COALESCE((p_event->>'event_version')::integer, 1);
  v_sm_version := COALESCE((p_event->>'state_machine_version')::integer, 1);
  v_metadata := COALESCE(p_event->'metadata', '{}'::jsonb);
  v_device_id := NULLIF(btrim(p_event->>'device_id'), '');

  IF v_event_type IS NULL OR v_event_type NOT LIKE 'connectivity.%' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_event_type');
  END IF;

  IF v_sm_version <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unsupported_state_machine_version');
  END IF;

  SELECT jsonb_build_object(
    'ok', true,
    'deduplicated', true,
    'event_id', e.event_id,
    'session_id', e.session_id,
    'states', e.to_state,
    'state_machine_version', e.state_machine_version
  ) INTO v_existing
  FROM public.driver_connectivity_events e
  WHERE e.event_id = v_event_id
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  v_driver_id := (p_event->>'driver_id')::uuid;
  IF v_driver_id IS NULL THEN
    SELECT d.id INTO v_driver_id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  IF auth.uid() IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
     AND NOT EXISTS (
       SELECT 1 FROM public.drivers d
       WHERE d.id = v_driver_id AND d.user_id = auth.uid()
     )
  THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  IF NOT public.fn_connectivity_m14_enabled(v_driver_id) AND auth.uid() IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'connectivity_m14_disabled');
  END IF;

  v_layer := COALESCE(
    NULLIF(p_event->>'layer', ''),
    CASE
      WHEN v_event_type LIKE 'connectivity.session.%' THEN 'session'
      WHEN v_event_type LIKE 'connectivity.transport.%' THEN 'transport'
      WHEN v_event_type LIKE 'connectivity.presence.%' THEN 'presence'
      WHEN v_event_type LIKE 'connectivity.operational.%' THEN 'operational'
      ELSE 'session'
    END
  );

  -- Session start: close prior open authoritative session, create new
  IF v_event_type = 'connectivity.session.start' THEN
    IF v_device_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'device_id_required');
    END IF;

    UPDATE public.driver_sessions s
    SET
      ended_at = timezone('utc', now()),
      end_reason = 'session_replaced',
      presence_state = 'ended',
      operational_state = 'offline',
      is_authoritative = false,
      last_transition_at = timezone('utc', now())
    WHERE s.driver_id = v_driver_id
      AND s.is_authoritative = true
      AND s.ended_at IS NULL;

    INSERT INTO public.driver_sessions (
      driver_id, device_id, transport_state, presence_state, operational_state,
      connected_at, app_version, platform, push_token, state_machine_version
    ) VALUES (
      v_driver_id,
      v_device_id,
      'disconnected',
      'present',
      'offline',
      timezone('utc', now()),
      v_metadata->>'app_version',
      v_metadata->>'platform',
      v_metadata->>'push_token',
      v_sm_version
    )
    RETURNING * INTO v_session;

    v_from_state := jsonb_build_object('session', 'none');
    v_to_state := jsonb_build_object(
      'transport', v_session.transport_state,
      'presence', v_session.presence_state,
      'operational', v_session.operational_state
    );

    INSERT INTO public.driver_connectivity_events (
      event_id, event_version, state_machine_version,
      session_id, driver_id, event_type, layer,
      from_state, to_state, metadata, correlation_id
    ) VALUES (
      v_event_id, v_event_version, v_sm_version,
      v_session.id, v_driver_id, v_event_type, v_layer,
      v_from_state, v_to_state, v_metadata, v_event_id
    );

    RETURN jsonb_build_object(
      'ok', true,
      'event_id', v_event_id,
      'event_version', v_event_version,
      'state_machine_version', v_sm_version,
      'session_id', v_session.id,
      'states', v_to_state
    );
  END IF;

  -- Load authoritative open session for all other events
  SELECT * INTO v_session
  FROM public.driver_sessions s
  WHERE s.driver_id = v_driver_id
    AND s.is_authoritative = true
    AND s.ended_at IS NULL
  ORDER BY s.created_at DESC
  LIMIT 1;

  IF v_session.id IS NULL AND v_event_type <> 'connectivity.session.start' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_active_session');
  END IF;

  IF (p_event->>'session_id') IS NOT NULL
     AND (p_event->>'session_id')::uuid IS DISTINCT FROM v_session.id
  THEN
    RETURN jsonb_build_object('ok', false, 'error', 'session_mismatch');
  END IF;

  v_from_state := jsonb_build_object(
    'transport', v_session.transport_state,
    'presence', v_session.presence_state,
    'operational', v_session.operational_state
  );

  IF v_event_type = 'connectivity.session.end' THEN
    UPDATE public.driver_sessions s
    SET
      ended_at = timezone('utc', now()),
      end_reason = COALESCE(v_metadata->>'reason', 'user_action'),
      presence_state = 'ended',
      operational_state = 'offline',
      last_transition_at = timezone('utc', now())
    WHERE s.id = v_session.id
    RETURNING * INTO v_session;

    v_to_state := jsonb_build_object(
      'transport', v_session.transport_state,
      'presence', v_session.presence_state,
      'operational', v_session.operational_state
    );
  ELSIF v_event_type LIKE 'connectivity.transport.%' THEN
    v_target_transport := public.fn_connectivity_transport_target(v_session.transport_state, v_event_type);
    IF v_target_transport IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'illegal_transition',
        'from', v_from_state,
        'event_type', v_event_type
      );
    END IF;
    UPDATE public.driver_sessions s
    SET
      transport_state = v_target_transport,
      last_realtime_at = timezone('utc', now()),
      last_transition_at = timezone('utc', now())
    WHERE s.id = v_session.id
    RETURNING * INTO v_session;

    v_to_state := jsonb_build_object(
      'transport', v_session.transport_state,
      'presence', v_session.presence_state,
      'operational', v_session.operational_state
    );
  ELSIF v_event_type LIKE 'connectivity.operational.%' THEN
    v_target_operational := public.fn_connectivity_operational_target(v_session.operational_state, v_event_type);
    IF v_target_operational IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'illegal_transition',
        'from', v_from_state,
        'event_type', v_event_type
      );
    END IF;
    UPDATE public.driver_sessions s
    SET
      operational_state = v_target_operational,
      last_transition_at = timezone('utc', now())
    WHERE s.id = v_session.id
    RETURNING * INTO v_session;

    v_to_state := jsonb_build_object(
      'transport', v_session.transport_state,
      'presence', v_session.presence_state,
      'operational', v_session.operational_state
    );
  ELSE
    RETURN jsonb_build_object('ok', false, 'error', 'unsupported_event_m14', 'event_type', v_event_type);
  END IF;

  INSERT INTO public.driver_connectivity_events (
    event_id, event_version, state_machine_version,
    session_id, driver_id, event_type, layer,
    from_state, to_state, metadata, correlation_id
  ) VALUES (
    v_event_id, v_event_version, v_sm_version,
    v_session.id, v_driver_id, v_event_type, v_layer,
    v_from_state, v_to_state, v_metadata, v_event_id
  );

  RETURN jsonb_build_object(
    'ok', true,
    'event_id', v_event_id,
    'event_version', v_event_version,
    'state_machine_version', v_sm_version,
    'session_id', v_session.id,
    'states', v_to_state
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_session_current(p_driver_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_session public.driver_sessions%ROWTYPE;
BEGIN
  v_driver_id := p_driver_id;
  IF v_driver_id IS NULL THEN
    SELECT d.id INTO v_driver_id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1;
  END IF;
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_a_driver');
  END IF;

  SELECT * INTO v_session
  FROM public.driver_sessions s
  WHERE s.driver_id = v_driver_id AND s.is_authoritative = true AND s.ended_at IS NULL
  ORDER BY s.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('session', NULL);
  END IF;

  RETURN jsonb_build_object(
    'session_id', v_session.id,
    'device_id', v_session.device_id,
    'transport', v_session.transport_state,
    'presence', v_session.presence_state,
    'operational', v_session.operational_state,
    'connected_at', v_session.connected_at,
    'last_heartbeat_at', v_session.last_heartbeat_at,
    'last_realtime_at', v_session.last_realtime_at,
    'state_machine_version', v_session.state_machine_version
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_connectivity_summary(p_driver_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_legacy text;
  v_session jsonb;
BEGIN
  v_driver_id := p_driver_id;
  IF v_driver_id IS NULL THEN
    SELECT d.id INTO v_driver_id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1;
  END IF;
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_a_driver');
  END IF;

  SELECT d.status INTO v_legacy FROM public.drivers d WHERE d.id = v_driver_id;
  v_session := public.fn_driver_session_current(v_driver_id);

  RETURN jsonb_build_object(
    'driver_id', v_driver_id,
    'legacy_status', v_legacy,
    'session', v_session,
    'layers_aligned', (
      v_session->>'session_id' IS NULL
      OR v_legacy IS NOT DISTINCT FROM (v_session->>'operational')
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_connectivity_m14_enabled(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_connectivity_operational_target(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_connectivity_transport_target(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_connectivity_transition(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_session_current(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_connectivity_summary(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_driver_connectivity_transition(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_session_current(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_connectivity_summary(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_connectivity_m14_enabled(uuid) TO service_role;
