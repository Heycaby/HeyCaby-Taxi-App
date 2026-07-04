-- Drivers set their own prices on HeyCaby, so every online driver must have
-- at least one usable active tariff before they can receive ride requests.

ALTER TABLE public.driver_rate_profiles
  ADD COLUMN IF NOT EXISTS vat_percentage numeric(5,2) NOT NULL DEFAULT 9.00;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'driver_rate_profiles_vat_percentage_range'
  ) THEN
    ALTER TABLE public.driver_rate_profiles
      ADD CONSTRAINT driver_rate_profiles_vat_percentage_range
      CHECK (vat_percentage >= 0 AND vat_percentage <= 100);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.fn_driver_has_initial_tariff(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = p_driver_id
      AND COALESCE(rp.is_active, false) IS TRUE
      AND rp.base_fare IS NOT NULL
      AND rp.base_fare >= 0
      AND rp.per_km_rate IS NOT NULL
      AND rp.per_km_rate > 0
      AND rp.per_min_rate IS NOT NULL
      AND rp.per_min_rate >= 0
      AND rp.vat_percentage IS NOT NULL
      AND rp.vat_percentage >= 0
      AND rp.vat_percentage <= 100
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
  v_next_milestone int := 10;
  v_stage int := 0;
  v_onboarding_v2 boolean := false;
  v_review boolean := false;
  v_skip_gates boolean := false;
  v_can_go_online boolean := true;
  v_missing text[] := ARRAY[]::text[];
  v_status_message text := 'Ready to go online';
  v_checklist jsonb := '[]'::jsonb;
  v_item jsonb;
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
  v_initial_tariff_ok boolean;
  v_now timestamptz := timezone('utc', now());
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_go_online', false,
      'checklist', '[]'::jsonb,
      'status_message', 'Driver not found',
      'completed_rides', 0,
      'next_milestone_at', 10,
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

  IF v_completed < 10 THEN
    v_next_milestone := 10;
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
  v_initial_tariff_ok := public.fn_driver_has_initial_tariff(p_driver_id);

  v_required := jsonb_build_object(
    'vehicle_plate', true,
    'terms_of_service', true,
    'indemnification_quiz', true,
    'profile_photo', true,
    'vehicle_photos', true,
    'initial_tariff', true
  );
  IF v_onboarding_v2 THEN
    IF v_completed >= 10 THEN
      v_required := v_required || jsonb_build_object(
        'rijbewijs_verified', true,
        'kvk_number', true,
        'kvk_address', true,
        'chauffeurspas', true,
        'taxi_insurance', true
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
      'rijbewijs_verified', true,
      'initial_tariff', true
    );
  END IF;

  v_checklist := public.fn_driver_readiness_checklist_v2(
    v_d, v_onboarding_v2, v_completed,
    v_profile_photo_ok, v_vehicle_photos_ok, v_terms_ok, v_indemn_ok,
    v_kvk_ok, v_kvk_addr_ok, v_chauffeur_ok, v_insurance_ok,
    v_plate_ok, v_rijbewijs_ok
  );

  v_checklist := v_checklist || jsonb_build_array(
    jsonb_build_object(
      'key', 'initial_tariff',
      'label', 'Initial tariff',
      'complete', v_initial_tariff_ok,
      'action', '/driver/tariffs',
      'note', CASE
        WHEN v_initial_tariff_ok THEN 'Price ready'
        ELSE 'Required before going online'
      END
    )
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
    IF 'initial_tariff' = ANY(v_missing) THEN
      v_status_message := 'Set your first tariff before going online';
    ELSIF v_onboarding_v2 THEN
      IF v_completed >= 10 THEN
        v_status_message := format(
          'After 10 rides: verification required (%s item(s) missing)',
          array_length(v_missing, 1)
        );
      ELSE
        v_status_message := format(
          'Complete onboarding to go online (%s item(s) missing)',
          array_length(v_missing, 1)
        );
      END IF;
    ELSE
      v_status_message := format(
        '%s item(s) missing before going online',
        array_length(v_missing, 1)
      );
    END IF;
  ELSIF v_onboarding_v2 AND v_completed >= 10 THEN
    IF v_d.chauffeurspas_expiry IS NOT NULL AND v_d.chauffeurspas_expiry < v_now THEN
      v_can_go_online := false;
      v_status_message := 'Chauffeurspas has expired';
      v_missing := ARRAY['chauffeurspas'];
    ELSIF v_d.taxi_insurance_expiry IS NOT NULL AND v_d.taxi_insurance_expiry < v_now THEN
      v_can_go_online := false;
      v_status_message := 'Taxi insurance has expired';
      v_missing := ARRAY['taxi_insurance'];
    ELSE
      v_status_message := 'Onboarding V2: verification met';
    END IF;
  ELSIF v_onboarding_v2 THEN
    v_status_message := 'Onboarding V2: plate + legal minimum met';
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
    'verification_required', v_onboarding_v2 AND v_completed >= 10 AND NOT v_rijbewijs_ok,
    'premium_eligible', v_completed >= 100
      AND v_profile_photo_ok AND v_vehicle_photos_ok AND v_terms_ok AND v_indemn_ok
      AND v_kvk_ok AND v_kvk_addr_ok AND v_chauffeur_ok AND v_insurance_ok
      AND v_plate_ok AND v_rijbewijs_ok AND v_initial_tariff_ok
  );
END;
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
  v_user_id uuid := auth.uid();
  v_d public.drivers%ROWTYPE;
  v_readiness jsonb;
  v_primary_missing text;
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

  IF v_status = 'available' THEN
    v_readiness := public.fn_driver_readiness_eval(v_driver_id);
    IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
      v_primary_missing := COALESCE(v_readiness->'missing_docs'->>0, 'missing_docs');
      RETURN jsonb_build_object(
        'status', 'offline',
        'blocked_reason', CASE
          WHEN v_primary_missing = 'initial_tariff' THEN 'missing_tariff'
          ELSE v_primary_missing
        END,
        'message', COALESCE(v_readiness->>'status_message', 'Compliance incomplete'),
        'redirect', CASE
          WHEN v_primary_missing = 'initial_tariff' THEN '/driver/tariffs'
          ELSE NULL
        END,
        'readiness', v_readiness
      );
    END IF;

    v_flags := public.fn_app_config_jsonb('feature_flags');
    v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

    IF NOT v_skip_gates AND NOT public.fn_driver_is_review_account(v_user_id) THEN
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
      user_id,
      driver_id,
      latitude,
      longitude,
      country_code,
      updated_at
    )
    VALUES (
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

REVOKE ALL ON FUNCTION public.fn_driver_has_initial_tariff(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_has_initial_tariff(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_driver_has_initial_tariff(uuid) IS
  'Returns true only when the driver has at least one active tariff with the minimum pricing fields required before going online.';
