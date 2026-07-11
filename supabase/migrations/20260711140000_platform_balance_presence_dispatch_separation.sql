-- Platform Balance controls eligibility for new HeyCaby rides, not app presence.
-- A driver may be online while platform_ride_eligible=false. Dispatch and
-- acceptance continue to enforce fn_driver_can_accept_rides atomically.

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
  v_allowed boolean;
BEGIN
  v_billing := public.fn_driver_can_accept_rides(p_driver_id);
  v_summary := public.fn_driver_billing_summary(p_driver_id);
  v_allowed := COALESCE((v_billing->>'allowed')::boolean, false);

  RETURN jsonb_build_object(
    'status', COALESCE(v_summary->>'status', v_billing->>'status', 'UNKNOWN'),
    'balance_state', COALESCE(v_billing->>'balance_state', 'current'),
    'outstanding', COALESCE((v_summary->>'outstanding')::bigint, 0),
    'outstanding_cents', COALESCE((v_billing->>'outstanding_cents')::bigint, 0),
    'limit', COALESCE((v_summary->>'limit')::bigint, 0),
    'remaining', COALESCE((v_summary->>'remaining')::bigint, 0),
    'currency', COALESCE(v_summary->>'currency', v_billing->>'currency', 'EUR'),
    'can_accept_rides', v_allowed,
    'ride_requests_paused', NOT v_allowed,
    'in_grace_period', COALESCE((v_billing->>'in_grace_period')::boolean, false),
    'blocked_reason', v_billing->>'reason',
    'eligibility_reason', CASE
      WHEN v_allowed THEN NULL
      ELSE 'platform_balance_overdue'
    END,
    'allowed', v_allowed
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_runtime(p_driver_id uuid DEFAULT NULL::uuid)
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
  v_platform_ride_eligible boolean;
  v_balance_state text;
  v_eligibility_reason text;
BEGIN
  IF p_driver_id IS NOT NULL THEN
    IF auth.uid() IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()
       )
       AND NOT EXISTS (
         SELECT 1
         FROM public.drivers d
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
  v_dispatch := public.fn_driver_runtime_dispatch(
    v_driver_id,
    v_permissions,
    v_billing
  );
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
  v_platform_ride_eligible := COALESCE((v_billing->>'allowed')::boolean, false);
  v_balance_state := COALESCE(v_billing->>'balance_state', 'current');
  v_eligibility_reason := CASE
    WHEN v_platform_ride_eligible THEN NULL
    ELSE COALESCE(v_billing->>'eligibility_reason', 'platform_balance_overdue')
  END;
  v_platform_health := CASE
    WHEN COALESCE(v_billing->>'status', 'GOOD') IN ('GOOD', 'GRACE') THEN 'GOOD'
    WHEN v_billing->>'status' = 'LOCKED' THEN 'LOCKED'
    ELSE 'ATTENTION'
  END;

  RETURN jsonb_build_object(
    'runtime_version', 3,
    'generated_at', v_generated_at,
    'ok', true,
    -- Presence readiness is deliberately independent of Platform Balance.
    'can_go_online', COALESCE((v_permissions->>'can_go_online')::boolean, false),
    'platform_ride_eligible', v_platform_ride_eligible,
    'platform_dispatch_eligible_now', v_dispatch_eligible,
    'eligibility_reason', v_eligibility_reason,
    'balance_state', v_balance_state,
    'plate_verified', COALESCE((v_onboarding->>'plate_verified')::boolean, false),
    'terms_accepted', COALESCE((v_onboarding->>'terms_accepted')::boolean, false),
    'completed_rides', COALESCE((v_permissions->>'completed_rides')::int, 0),
    'next_milestone', COALESCE((v_permissions->>'next_milestone_at')::int, 0),
    'verification_required', COALESCE((v_permissions->>'verification_required')::boolean, false),
    -- Kept for older clients; this means ride eligibility, not app access.
    'billing_allowed', v_platform_ride_eligible,
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
        'outstanding', COALESCE((v_billing->>'outstanding')::bigint, 0),
        'limit', COALESCE((v_billing->>'limit')::bigint, 0),
        'remaining', COALESCE((v_billing->>'remaining')::bigint, 0),
        'currency', v_billing->>'currency',
        'can_accept_rides', v_platform_ride_eligible
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

CREATE OR REPLACE FUNCTION public.fn_driver_set_status(
  p_status text,
  p_lat double precision DEFAULT NULL::double precision,
  p_lng double precision DEFAULT NULL::double precision
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_user_id uuid := auth.uid();
  v_d public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_billing jsonb;
  v_flags jsonb;
  v_skip_gates boolean := false;
  v_review_account boolean := false;
  v_status text := lower(trim(COALESCE(p_status, '')));
  v_has_fresh_gps boolean := false;
  v_has_tariff boolean := false;
  v_late_join jsonb;
  v_platform_ride_eligible boolean := true;
  v_eligibility_reason text;
  v_balance_state text := 'current';
BEGIN
  IF v_status NOT IN ('available', 'offline', 'on_break') THEN
    RETURN jsonb_build_object(
      'success', false,
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
      'success', false,
      'status', 'offline',
      'blocked_reason', 'not_a_driver',
      'message', 'Driver profile not found'
    );
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  v_flags := public.fn_app_config_jsonb('feature_flags');
  v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);
  v_review_account := public.fn_driver_is_review_account(v_user_id);

  IF v_status = 'available' THEN
    v_readiness := public.fn_driver_readiness_eval(v_driver_id);
    IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'status', 'offline',
        'blocked_reason', 'missing_docs',
        'message', COALESCE(v_readiness->>'status_message', 'Compliance incomplete'),
        'readiness', v_readiness
      );
    END IF;

    IF NOT v_skip_gates AND NOT v_review_account THEN
      v_has_fresh_gps := (p_lat IS NOT NULL AND p_lng IS NOT NULL)
        OR EXISTS (
          SELECT 1
          FROM public.driver_locations dl
          WHERE dl.driver_id = v_driver_id
            AND dl.latitude IS NOT NULL
            AND dl.longitude IS NOT NULL
            AND dl.updated_at > now() - interval '5 minutes'
        );
      IF NOT v_has_fresh_gps THEN
        RETURN jsonb_build_object(
          'success', false,
          'status', 'offline',
          'blocked_reason', 'missing_location',
          'message', 'Enable location to go online',
          'redirect', '/driver/location'
        );
      END IF;

      v_has_tariff := EXISTS (
        SELECT 1
        FROM public.driver_rate_profiles rp
        WHERE rp.driver_id = v_driver_id AND rp.is_active = true
      );
      IF NOT v_has_tariff THEN
        RETURN jsonb_build_object(
          'success', false,
          'status', 'offline',
          'blocked_reason', 'missing_tariff',
          'message', 'Set your first tariff before going online',
          'redirect', '/driver/tariffs'
        );
      END IF;

      PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);
    END IF;
  END IF;

  -- Billing is evaluated independently from presence. Review/test accounts
  -- keep their intentional bypass, while normal accounts expose the real
  -- platform-dispatch eligibility state.
  IF NOT v_skip_gates AND NOT v_review_account THEN
    v_billing := public.fn_driver_can_accept_rides(v_driver_id);
    v_platform_ride_eligible := COALESCE((v_billing->>'allowed')::boolean, false);
    v_balance_state := COALESCE(v_billing->>'balance_state', 'current');
    v_eligibility_reason := CASE
      WHEN v_platform_ride_eligible THEN NULL
      ELSE 'platform_balance_overdue'
    END;
  ELSE
    v_billing := jsonb_build_object(
      'allowed', true,
      'balance_state', 'current',
      'ride_requests_paused', false
    );
  END IF;

  UPDATE public.drivers
  SET status = v_status::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = v_driver_id;

  IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    INSERT INTO public.driver_locations (
      user_id,
      driver_id,
      latitude,
      longitude,
      country_code,
      updated_at
    ) VALUES (
      v_user_id,
      v_driver_id,
      p_lat,
      p_lng,
      COALESCE(v_d.country_code, 'NL'),
      timezone('utc', now())
    )
    ON CONFLICT (user_id) DO UPDATE
    SET driver_id = EXCLUDED.driver_id,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        country_code = EXCLUDED.country_code,
        updated_at = EXCLUDED.updated_at;
  END IF;

  IF v_status = 'available' THEN
    IF v_platform_ride_eligible THEN
      v_late_join := public.fn_dispatch_recheck_pending_on_driver_online(v_driver_id);
    ELSE
      v_late_join := jsonb_build_object(
        'ok', true,
        'skipped', true,
        'reason', 'platform_balance_overdue'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_status,
    'driver_status', v_status,
    'platform_ride_eligible', v_platform_ride_eligible,
    'eligibility_reason', v_eligibility_reason,
    'balance_state', v_balance_state,
    'billing', v_billing,
    'message', CASE
      WHEN v_status = 'available' THEN 'Online'
      WHEN v_status = 'on_break' THEN 'On break'
      ELSE 'Offline'
    END,
    'late_join_dispatch', v_late_join
  );
END;
$$;

-- Billing changes should restore the Home warning and runtime without logout.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'billing_ledger'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.billing_ledger;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'driver_platform_balance_cycles'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.driver_platform_balance_cycles;
  END IF;
END;
$$;

-- Explicit grants prevent later CREATE OR REPLACE operations from restoring
-- default PUBLIC execution on security-definer functions.
REVOKE ALL ON FUNCTION public.fn_driver_runtime_billing(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_runtime_billing(uuid)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_runtime(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_runtime(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_set_status(text, double precision, double precision)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_set_status(text, double precision, double precision)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_accept_scheduled_ride(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_scheduled_ride(uuid)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) IS
  'Sets driver presence. Platform Balance is returned as separate dispatch eligibility and never blocks presence.';

COMMENT ON FUNCTION public.fn_driver_runtime(uuid) IS
  'Driver runtime v3. can_go_online is presence readiness; platform_ride_eligible is eligibility for new HeyCaby rides.';
