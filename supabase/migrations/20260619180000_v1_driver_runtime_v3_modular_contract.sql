-- Driver runtime v3 contract: modular internals, runtime_version + generated_at.
-- Public surface remains fn_driver_runtime() — one RPC, many focused helpers.

-- ---------------------------------------------------------------------------
-- Shared config helpers (idempotent)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_app_config_text(p_key text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT value FROM public.app_config WHERE key = p_key LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.fn_app_config_jsonb(p_key text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(value::jsonb, '{}'::jsonb)
  FROM public.app_config
  WHERE key = p_key
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_is_review_account(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enabled text;
  v_email text;
  v_user_email text;
BEGIN
  v_enabled := public.fn_app_config_text('apple_review_enabled');
  IF COALESCE(v_enabled, 'false') NOT IN ('true', '1', 'yes') THEN
    RETURN false;
  END IF;
  v_email := lower(trim(public.fn_app_config_text('apple_review_email')));
  IF v_email IS NULL OR v_email = '' THEN
    RETURN false;
  END IF;
  SELECT lower(trim(u.email)) INTO v_user_email
  FROM auth.users u
  WHERE u.id = p_user_id
  LIMIT 1;
  RETURN v_user_email IS NOT NULL AND v_user_email = v_email;
END;
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: configuration (feature flags + search)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_configuration()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'search', public.fn_app_config_jsonb('search_config'),
    'feature_flags', public.fn_app_config_jsonb('feature_flags')
  );
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: permissions / readiness (progressive verification)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_readiness_checklist_v2(
  p_d public.drivers,
  p_onboarding_v2 boolean,
  p_completed int,
  p_profile_photo_ok boolean,
  p_vehicle_photos_ok boolean,
  p_terms_ok boolean,
  p_indemn_ok boolean,
  p_kvk_ok boolean,
  p_kvk_addr_ok boolean,
  p_chauffeur_ok boolean,
  p_insurance_ok boolean,
  p_plate_ok boolean,
  p_rijbewijs_ok boolean
)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_build_array(
    jsonb_build_object('key', 'profile_photo', 'label', 'Profile photo', 'complete', p_profile_photo_ok, 'action', '/driver/profile/photo', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 50 AND NOT p_profile_photo_ok THEN 'Required after 50 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'vehicle_photos', 'label', 'Vehicle photos', 'complete', p_vehicle_photos_ok, 'action', '/driver/vehicle', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 50 AND NOT p_vehicle_photos_ok THEN 'Required after 50 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'terms_of_service', 'label', 'Terms of service accepted', 'complete', p_terms_ok, 'action', '/driver/terms'),
    jsonb_build_object('key', 'indemnification_quiz', 'label', 'Indemnification read & quiz passed', 'complete', p_indemn_ok, 'action', '/driver/indemnification', 'note', 'Read the indemnification document and pass the short quiz'),
    jsonb_build_object('key', 'kvk_number', 'label', 'KVK number', 'complete', p_kvk_ok, 'action', '/driver/documents/kvk', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 50 AND NOT p_kvk_ok THEN 'Required after 50 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'kvk_address', 'label', 'KVK business address', 'complete', p_kvk_addr_ok, 'action', '/driver/documents/kvk', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 50 AND NOT p_kvk_addr_ok THEN 'Required after 50 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'chauffeurspas', 'label', 'Chauffeurspas (number & expiry)', 'complete', p_chauffeur_ok, 'action', '/driver/documents/chauffeurspas', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 50 AND NOT p_chauffeur_ok THEN 'Required after 50 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'taxi_insurance', 'label', 'Taxi insurance (provider, policy, photo & expiry)', 'complete', p_insurance_ok, 'action', '/driver/documents/insurance', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 50 AND NOT p_insurance_ok THEN 'Required after 50 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'vehicle_plate', 'label', 'Vehicle plate', 'complete', p_plate_ok, 'action', '/driver/onboarding/plate'),
    jsonb_build_object('key', 'rijbewijs_verified', 'label', 'Driving licence verified (Veriff)', 'complete', p_rijbewijs_ok, 'action', '/driver/veriff', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 20 AND NOT p_rijbewijs_ok THEN 'Required after 20 completed rides' ELSE 'Admin confirms licence after review (e.g. Veriff)' END)
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_readiness_eval(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_d public.drivers%ROWTYPE;
  v_completed int := 0;
  v_next_milestone int := 20;
  v_stage int := 0;
  v_onboarding_v2 boolean := false;
  v_review boolean := false;
  v_skip_gates boolean := false;
  v_can_go_online boolean := true;
  v_missing text[] := ARRAY[]::text[];
  v_status_message text := 'Ready to go online';
  v_checklist jsonb := '[]'::jsonb;
  v_item jsonb;
  v_note text;
  v_required jsonb := '{}'::jsonb;
  v_flags jsonb;
  v_profile_photo_ok boolean;
  v_vehicle_photos_ok boolean;
  v_terms_ok boolean;
  v_indemn_ok boolean;
  v_kvk_ok boolean;
  v_kvk_addr_ok boolean;
  v_chauffeur_ok boolean;
  v_insurance_ok boolean;
  v_plate_ok boolean;
  v_rijbewijs_ok boolean;
  v_now timestamptz := timezone('utc', now());
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_go_online', false,
      'checklist', '[]'::jsonb,
      'status_message', 'Driver not found',
      'completed_rides', 0,
      'next_milestone_at', 20,
      'onboarding_v2_stage', 0
    );
  END IF;

  v_flags := public.fn_app_config_jsonb('feature_flags');
  v_onboarding_v2 := COALESCE((v_flags->>'driver_onboarding_v2')::boolean, false);
  v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

  v_review := public.fn_driver_is_review_account(
    (SELECT user_id FROM public.drivers WHERE id = p_driver_id LIMIT 1)
  );

  IF v_review OR v_skip_gates THEN
    RETURN jsonb_build_object(
      'can_go_online', true,
      'gates_skipped', true,
      'checklist', jsonb_build_array(
        jsonb_build_object(
          'key', CASE WHEN v_review THEN 'review_account' ELSE 'test_mode' END,
          'label', CASE WHEN v_review THEN 'Review account (App Store)' ELSE 'E2E test mode' END,
          'complete', true,
          'note', 'Compliance checks bypassed'
        )
      ),
      'status_message', CASE WHEN v_review THEN 'Review account bypass' ELSE 'Test mode: gates bypassed' END,
      'compliance_type', lower(COALESCE(v_d.country_code, 'NL')),
      'completed_rides', public.fn_driver_lifetime_completed_rides(p_driver_id),
      'next_milestone_at', 0,
      'onboarding_v2_stage', 2,
      'verification_required', false,
      'premium_eligible', false
    );
  END IF;

  v_completed := public.fn_driver_lifetime_completed_rides(p_driver_id);

  IF v_completed < 20 THEN
    v_next_milestone := 20;
    v_stage := 0;
  ELSIF v_completed < 50 THEN
    v_next_milestone := 50;
    v_stage := 1;
  ELSIF v_completed < 100 THEN
    v_next_milestone := 100;
    v_stage := 2;
  ELSE
    v_next_milestone := 0;
    v_stage := 3;
  END IF;

  v_profile_photo_ok := length(trim(COALESCE(v_d.profile_photo_url, ''))) > 0;
  v_vehicle_photos_ok := COALESCE(
    array_length(
      ARRAY(
        SELECT 1 FROM unnest(COALESCE(v_d.vehicle_photo_urls, ARRAY[]::text[])) u(url)
        WHERE length(trim(url)) > 0
      ),
      1
    ),
    0
  ) > 0;
  v_terms_ok := v_d.terms_accepted_at IS NOT NULL;
  v_indemn_ok := v_d.indemnification_read_at IS NOT NULL
    AND COALESCE(v_d.indemnification_quiz_passed, false);
  v_kvk_ok := length(trim(COALESCE(v_d.kvk_number, ''))) > 0;
  v_kvk_addr_ok := length(trim(COALESCE(v_d.kvk_address, ''))) > 0;
  v_chauffeur_ok := length(trim(COALESCE(v_d.chauffeurspas_number, ''))) > 0
    AND v_d.chauffeurspas_expiry IS NOT NULL;
  v_insurance_ok := length(trim(COALESCE(v_d.taxi_insurance_provider, ''))) > 0
    AND length(trim(COALESCE(v_d.taxi_insurance_policy_number, ''))) > 0
    AND length(trim(COALESCE(v_d.taxi_insurance_photo_url, ''))) > 0
    AND v_d.taxi_insurance_expiry IS NOT NULL;
  v_plate_ok := length(trim(COALESCE(v_d.vehicle_plate, ''))) > 0;
  v_rijbewijs_ok := COALESCE(v_d.rijbewijs_verified, false);

  v_required := jsonb_build_object(
    'vehicle_plate', true,
    'terms_of_service', true,
    'indemnification_quiz', true
  );
  IF v_onboarding_v2 THEN
    IF v_completed >= 20 THEN
      v_required := v_required || jsonb_build_object('rijbewijs_verified', true);
    END IF;
    IF v_completed >= 50 THEN
      v_required := v_required || jsonb_build_object(
        'kvk_number', true,
        'kvk_address', true,
        'chauffeurspas', true,
        'taxi_insurance', true,
        'profile_photo', true,
        'vehicle_photos', true
      );
    END IF;
  ELSE
    v_required := jsonb_build_object(
      'profile_photo', true,
      'vehicle_photos', true,
      'terms_of_service', true,
      'indemnification_quiz', true,
      'kvk_number', true,
      'kvk_address', true,
      'chauffeurspas', true,
      'taxi_insurance', true,
      'vehicle_plate', true,
      'rijbewijs_verified', true
    );
  END IF;

  v_checklist := public.fn_driver_readiness_checklist_v2(
    v_d, v_onboarding_v2, v_completed,
    v_profile_photo_ok, v_vehicle_photos_ok, v_terms_ok, v_indemn_ok,
    v_kvk_ok, v_kvk_addr_ok, v_chauffeur_ok, v_insurance_ok,
    v_plate_ok, v_rijbewijs_ok
  );

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_checklist)
  LOOP
    IF COALESCE((v_item->>'complete')::boolean, false) THEN
      CONTINUE;
    END IF;
    IF COALESCE((v_required->>(v_item->>'key'))::boolean, false) THEN
      v_missing := array_append(v_missing, v_item->>'key');
    END IF;
  END LOOP;

  IF array_length(v_missing, 1) IS NOT NULL THEN
    v_can_go_online := false;
    IF v_onboarding_v2 THEN
      IF v_completed >= 50 THEN
        v_status_message := format(
          'After 50 rides: full verification required (%s item(s) missing)',
          array_length(v_missing, 1)
        );
      ELSIF v_completed >= 20 THEN
        v_status_message := format(
          'After 20 rides: identity verification required (%s item(s) missing)',
          array_length(v_missing, 1)
        );
      ELSE
        v_status_message := format(
          'Plate + legal minimum required (%s item(s) missing)',
          array_length(v_missing, 1)
        );
      END IF;
    ELSE
      v_status_message := format(
        '%s item(s) missing before going online',
        array_length(v_missing, 1)
      );
    END IF;
  ELSIF v_onboarding_v2 AND v_completed >= 50 THEN
    IF v_d.chauffeurspas_expiry IS NOT NULL AND v_d.chauffeurspas_expiry < v_now THEN
      v_can_go_online := false;
      v_status_message := 'Chauffeurspas has expired';
      v_missing := ARRAY['chauffeurspas'];
    ELSIF v_d.taxi_insurance_expiry IS NOT NULL AND v_d.taxi_insurance_expiry < v_now THEN
      v_can_go_online := false;
      v_status_message := 'Taxi insurance has expired';
      v_missing := ARRAY['taxi_insurance'];
    ELSE
      v_status_message := 'Onboarding V2: full verification met';
    END IF;
  ELSIF v_onboarding_v2 THEN
    IF v_completed >= 20 THEN
      v_status_message := 'Onboarding V2: complete taxi licence docs before 50 rides';
    ELSE
      v_status_message := 'Onboarding V2: plate + legal minimum met';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'can_go_online', v_can_go_online,
    'gates_skipped', false,
    'checklist', v_checklist,
    'missing_docs', to_jsonb(v_missing),
    'status_message', v_status_message,
    'compliance_type', lower(COALESCE(v_d.country_code, 'NL')),
    'completed_rides', v_completed,
    'next_milestone_at', v_next_milestone,
    'onboarding_v2_stage', v_stage,
    'verification_required', v_onboarding_v2 AND v_completed >= 20 AND NOT v_rijbewijs_ok,
    'premium_eligible', v_completed >= 100
      AND v_profile_photo_ok AND v_vehicle_photos_ok AND v_terms_ok AND v_indemn_ok
      AND v_kvk_ok AND v_kvk_addr_ok AND v_chauffeur_ok AND v_insurance_ok
      AND v_plate_ok AND v_rijbewijs_ok
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_permissions(p_driver_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.fn_driver_readiness_eval(p_driver_id);
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: billing
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_billing(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_billing jsonb;
  v_summary jsonb;
BEGIN
  v_billing := public.fn_driver_can_accept_rides(p_driver_id);
  v_summary := public.fn_driver_billing_summary(p_driver_id);
  RETURN jsonb_build_object(
    'status', v_summary->>'status',
    'outstanding', (v_summary->>'outstanding')::bigint,
    'limit', (v_summary->>'limit')::bigint,
    'remaining', (v_summary->>'remaining')::bigint,
    'currency', v_summary->>'currency',
    'can_accept_rides', (v_billing->>'allowed')::boolean,
    'blocked_reason', v_billing->>'reason',
    'allowed', (v_billing->>'allowed')::boolean
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: onboarding (plate, terms, shared vehicle session)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_onboarding(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_d public.drivers%ROWTYPE;
  v_vehicle_session record;
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;

  SELECT
    tvs.id IS NOT NULL AS session_active,
    COALESCE(tv.is_shared_fleet, false) AS shared_vehicle,
    tv.plate_normalized AS plate_normalized
  INTO v_vehicle_session
  FROM public.drivers d
  LEFT JOIN public.taxi_vehicles tv ON tv.id = d.taxi_vehicle_id
  LEFT JOIN public.taxi_vehicle_sessions tvs
    ON tvs.vehicle_id = tv.id
    AND tvs.driver_id = d.id
    AND tvs.is_active = true
    AND tvs.ended_at IS NULL
  WHERE d.id = p_driver_id;

  RETURN jsonb_build_object(
    'plate_verified', length(trim(COALESCE(v_d.vehicle_plate, ''))) > 0,
    'terms_accepted', v_d.terms_accepted_at IS NOT NULL,
    'shared_vehicle', COALESCE(v_vehicle_session.shared_vehicle, false),
    'vehicle_session_active', COALESCE(v_vehicle_session.session_active, false),
    'plate', v_vehicle_session.plate_normalized
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: connectivity (Program 2 expands here)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_connectivity(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_d public.drivers%ROWTYPE;
  v_session public.driver_sessions%ROWTYPE;
  v_layers_aligned boolean;
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;

  SELECT * INTO v_session
  FROM public.driver_sessions s
  WHERE s.driver_id = p_driver_id AND s.is_authoritative = true AND s.ended_at IS NULL
  ORDER BY s.created_at DESC
  LIMIT 1;

  v_layers_aligned := (
    v_session.id IS NULL
    OR v_d.status::text IS NOT DISTINCT FROM v_session.operational_state
  );

  RETURN jsonb_build_object(
    'm14_enabled', public.fn_connectivity_m14_enabled(p_driver_id),
    'session_id', v_session.id,
    'transport', COALESCE(v_session.transport_state, 'disconnected'),
    'presence', COALESCE(v_session.presence_state, 'unknown'),
    'operational', COALESCE(v_session.operational_state, 'offline'),
    'last_heartbeat_at', v_session.last_heartbeat_at,
    'last_realtime_at', v_session.last_realtime_at,
    'legacy_status', v_d.status::text,
    'layers_aligned', v_layers_aligned,
    'state_machine_version', COALESCE(v_session.state_machine_version, 1)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: communication (ping cooldown, push, active ride chat)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_communication(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active_ride_id uuid;
  v_last_ping_event text;
  v_last_ping_at timestamptz;
  v_last_ping_automatic boolean := false;
  v_last_delivered_event text;
  v_last_delivered_at timestamptz;
  v_push_ok boolean;
  v_cooldown_sec int := 0;
  v_ping_metadata jsonb;
BEGIN
  SELECT rr.id INTO v_active_ride_id
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.status::text IN (
      'accepted', 'driver_arrived', 'driver_en_route', 'in_progress', 'assigned'
    )
  ORDER BY rr.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_active_ride_id IS NOT NULL THEN
    SELECT ral.event, ral.metadata, ral.occurred_at
    INTO v_last_ping_event, v_ping_metadata, v_last_ping_at
    FROM public.ride_audit_log ral
    WHERE ral.ride_id = v_active_ride_id
      AND ral.event LIKE 'driver.ping_%'
      AND ral.event NOT LIKE '%.delivered'
      AND ral.event NOT LIKE '%.opened'
    ORDER BY ral.occurred_at DESC
    LIMIT 1;

    SELECT ral.event, ral.occurred_at
    INTO v_last_delivered_event, v_last_delivered_at
    FROM public.ride_audit_log ral
    WHERE ral.ride_id = v_active_ride_id
      AND ral.event LIKE 'driver.ping_%.delivered'
    ORDER BY ral.occurred_at DESC
    LIMIT 1;

    v_last_ping_automatic := COALESCE((v_ping_metadata->>'automatic')::boolean, false);

    IF v_last_ping_at IS NOT NULL
       AND v_last_ping_at > timezone('utc', now()) - interval '30 seconds'
    THEN
      v_cooldown_sec := GREATEST(
        0,
        30 - EXTRACT(EPOCH FROM (timezone('utc', now()) - v_last_ping_at))::int
      );
    END IF;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.push_devices pd
    WHERE pd.driver_id = p_driver_id
      AND pd.fcm_token IS NOT NULL
      AND length(trim(pd.fcm_token)) > 10
  ) INTO v_push_ok;

  RETURN jsonb_build_object(
    'chat_available', v_active_ride_id IS NOT NULL,
    'push_available', v_push_ok,
    'active_ride_id', v_active_ride_id,
    'last_ping_event', v_last_ping_event,
    'last_ping_at', v_last_ping_at,
    'last_ping_automatic', v_last_ping_automatic,
    'last_ping_delivered', v_last_delivered_event IS NOT NULL,
    'last_ping_delivered_at', v_last_delivered_at,
    'cooldown_remaining_sec', v_cooldown_sec
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: dispatch eligibility (Program 3 expands here)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_dispatch(
  p_driver_id uuid,
  p_permissions jsonb,
  p_billing jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_d public.drivers%ROWTYPE;
  v_eligible boolean;
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;

  v_eligible :=
    COALESCE((p_billing->>'allowed')::boolean, false)
    AND v_d.status::text = 'available'
    AND COALESCE(v_d.compliance_status, '') IS DISTINCT FROM 'suspended'
    AND COALESCE((p_permissions->>'can_go_online')::boolean, false);

  RETURN jsonb_build_object(
    'eligible', v_eligible,
    'operational_status', v_d.status::text,
    'compliance_status', v_d.compliance_status
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Runtime module: notices (system messages derived from permissions)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime_notices(p_permissions jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notices jsonb := '[]'::jsonb;
BEGIN
  IF COALESCE((p_permissions->>'verification_required')::boolean, false) THEN
    v_notices := v_notices || jsonb_build_array(
      jsonb_build_object(
        'code', 'identity_verification_due',
        'severity', 'warning',
        'message', 'Identity verification required — complete Veriff to stay online after 20 rides.'
      )
    );
  END IF;

  IF COALESCE((p_permissions->>'premium_eligible')::boolean, false) THEN
    v_notices := v_notices || jsonb_build_array(
      jsonb_build_object(
        'code', 'premium_driver',
        'severity', 'info',
        'message', 'Premium driver milestone reached (100+ completed rides).'
      )
    );
  END IF;

  RETURN v_notices;
END;
$$;

-- ---------------------------------------------------------------------------
-- Public orchestrator: fn_driver_runtime (contract v3)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_runtime(p_driver_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_d public.drivers%ROWTYPE;
  v_generated_at timestamptz := timezone('utc', now());
  v_config jsonb;
  v_permissions jsonb;
  v_billing jsonb;
  v_onboarding jsonb;
  v_connectivity jsonb;
  v_communication jsonb;
  v_dispatch jsonb;
  v_notices jsonb;
  v_verified boolean;
  v_docs boolean;
  v_vehicle boolean;
  v_online boolean;
  v_platform_health text;
  v_dispatch_eligible boolean;
BEGIN
  IF p_driver_id IS NOT NULL THEN
    IF auth.uid() IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
       AND NOT EXISTS (
         SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
       )
    THEN
      RETURN jsonb_build_object(
        'runtime_version', 3,
        'generated_at', v_generated_at,
        'ok', false,
        'error', 'forbidden'
      );
    END IF;
    v_driver_id := p_driver_id;
  ELSE
    SELECT d.id INTO v_driver_id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'runtime_version', 3,
      'generated_at', v_generated_at,
      'ok', false,
      'error', 'not_a_driver'
    );
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'runtime_version', 3,
      'generated_at', v_generated_at,
      'ok', false,
      'error', 'driver_not_found'
    );
  END IF;

  v_config := public.fn_driver_runtime_configuration();
  v_permissions := public.fn_driver_runtime_permissions(v_driver_id);
  v_billing := public.fn_driver_runtime_billing(v_driver_id);
  v_onboarding := public.fn_driver_runtime_onboarding(v_driver_id);
  v_connectivity := public.fn_driver_runtime_connectivity(v_driver_id);
  v_communication := public.fn_driver_runtime_communication(v_driver_id);
  v_dispatch := public.fn_driver_runtime_dispatch(v_driver_id, v_permissions, v_billing);
  v_notices := public.fn_driver_runtime_notices(v_permissions);

  v_verified := COALESCE(v_d.profile_status = 'verified', false)
    OR COALESCE(v_d.is_verified_badge, false);
  v_docs := COALESCE(v_d.chauffeurspas_verified, false)
    AND COALESCE(v_d.rijbewijs_verified, false)
    AND COALESCE(v_d.taxi_insurance_verified, false);
  v_vehicle := COALESCE(v_d.vehicle_verified, false)
    OR COALESCE(v_d.vehicle_photos_approved, false);
  v_online := v_d.status::text = 'available';
  v_dispatch_eligible := COALESCE((v_dispatch->>'eligible')::boolean, false);

  v_platform_health := CASE
    WHEN COALESCE(v_billing->>'status', 'GOOD') IN ('GOOD', 'GRACE') THEN 'GOOD'
    WHEN v_billing->>'status' = 'LOCKED' THEN 'LOCKED'
    ELSE 'ATTENTION'
  END;

  RETURN jsonb_build_object(
    'runtime_version', 3,
    'generated_at', v_generated_at,
    'ok', true,
    'can_go_online', COALESCE((v_permissions->>'can_go_online')::boolean, false)
      AND COALESCE((v_billing->>'allowed')::boolean, true),
    'plate_verified', COALESCE((v_onboarding->>'plate_verified')::boolean, false),
    'terms_accepted', COALESCE((v_onboarding->>'terms_accepted')::boolean, false),
    'completed_rides', COALESCE((v_permissions->>'completed_rides')::int, 0),
    'next_milestone', COALESCE((v_permissions->>'next_milestone_at')::int, 0),
    'verification_required', COALESCE((v_permissions->>'verification_required')::boolean, false),
    'billing_allowed', COALESCE((v_billing->>'allowed')::boolean, false),
    'session_active', COALESCE((v_onboarding->>'vehicle_session_active')::boolean, false),
    'shared_vehicle', COALESCE((v_onboarding->>'shared_vehicle')::boolean, false),
    'platform_health', v_platform_health,
    'config', v_config,
    'permissions', v_permissions,
    'readiness', v_permissions,
    'billing', v_billing,
    'onboarding', v_onboarding,
    'connectivity', v_connectivity,
    'communication', v_communication,
    'dispatch', v_dispatch,
    'notices', v_notices,
    'platform_health_legacy', jsonb_build_object(
      'allowed', v_dispatch_eligible,
      'billing', jsonb_build_object(
        'status', v_billing->>'status',
        'outstanding', (v_billing->>'outstanding')::bigint,
        'limit', (v_billing->>'limit')::bigint,
        'remaining', (v_billing->>'remaining')::bigint,
        'currency', v_billing->>'currency',
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
      'connectivity', v_connectivity,
      'communication', v_communication,
      'dispatch', jsonb_build_object('eligible', v_dispatch_eligible)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_platform_health(p_driver_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    public.fn_driver_runtime(p_driver_id)->'platform_health_legacy',
    jsonb_build_object('allowed', false, 'error', 'runtime_unavailable')
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_set_status(
  p_status text,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_d public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_billing jsonb;
  v_flags jsonb;
  v_skip_gates boolean := false;
  v_status text := lower(trim(COALESCE(p_status, '')));
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
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'offline',
      'blocked_reason', 'not_a_driver',
      'message', 'Driver profile not found'
    );
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;

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

    v_flags := public.fn_app_config_jsonb('feature_flags');
    v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

    IF NOT v_skip_gates AND NOT public.fn_driver_is_review_account(auth.uid()) THEN
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
    INSERT INTO public.driver_locations (driver_id, latitude, longitude, country_code, updated_at)
    VALUES (
      v_driver_id,
      p_lat,
      p_lng,
      COALESCE(v_d.country_code, 'NL'),
      timezone('utc', now())
    )
    ON CONFLICT (driver_id) DO UPDATE
    SET latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        country_code = EXCLUDED.country_code,
        updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'message', CASE
      WHEN v_status = 'available' THEN 'Online'
      WHEN v_status = 'on_break' THEN 'On break'
      ELSE 'Offline'
    END
  );
END;
$$;

-- Internal modules: not callable by clients directly.
REVOKE ALL ON FUNCTION public.fn_app_config_text(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_app_config_jsonb(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_is_review_account(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_readiness_eval(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_readiness_checklist_v2(public.drivers, boolean, int, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_configuration() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_permissions(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_billing(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_onboarding(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_connectivity(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_communication(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_dispatch(uuid, jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime_notices(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_runtime(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_driver_runtime(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_readiness_eval(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_health(uuid) TO authenticated, service_role;
