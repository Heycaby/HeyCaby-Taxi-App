-- Passive onboarding: plate + legal minimum only until 10 completed rides.
-- Progressive verification (identity + taxi docs) unlocks at 10 rides.

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
    jsonb_build_object('key', 'profile_photo', 'label', 'Profile photo', 'complete', p_profile_photo_ok, 'action', '/driver/profile/photo', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_profile_photo_ok THEN 'Required after 10 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'vehicle_photos', 'label', 'Vehicle photos', 'complete', p_vehicle_photos_ok, 'action', '/driver/vehicle', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_vehicle_photos_ok THEN 'Required after 10 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'terms_of_service', 'label', 'Terms of service accepted', 'complete', p_terms_ok, 'action', '/driver/terms'),
    jsonb_build_object('key', 'indemnification_quiz', 'label', 'Indemnification read & quiz passed', 'complete', p_indemn_ok, 'action', '/driver/indemnification', 'note', 'Read the indemnification document and pass the short quiz'),
    jsonb_build_object('key', 'kvk_number', 'label', 'KVK number', 'complete', p_kvk_ok, 'action', '/driver/documents/kvk', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_kvk_ok THEN 'Required after 10 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'kvk_address', 'label', 'KVK business address', 'complete', p_kvk_addr_ok, 'action', '/driver/documents/kvk', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_kvk_addr_ok THEN 'Required after 10 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'chauffeurspas', 'label', 'Chauffeurspas (number & expiry)', 'complete', p_chauffeur_ok, 'action', '/driver/documents/chauffeurspas', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_chauffeur_ok THEN 'Required after 10 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'taxi_insurance', 'label', 'Taxi insurance (provider, policy, photo & expiry)', 'complete', p_insurance_ok, 'action', '/driver/documents/insurance', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_insurance_ok THEN 'Required after 10 completed rides' ELSE NULL END),
    jsonb_build_object('key', 'vehicle_plate', 'label', 'Vehicle plate', 'complete', p_plate_ok, 'action', '/driver/onboarding/plate'),
    jsonb_build_object('key', 'rijbewijs_verified', 'label', 'Driving licence verified (Veriff)', 'complete', p_rijbewijs_ok, 'action', '/driver/veriff', 'note', CASE WHEN p_onboarding_v2 AND p_completed < 10 AND NOT p_rijbewijs_ok THEN 'Required after 10 completed rides' ELSE 'Admin confirms licence after review (e.g. Veriff)' END)
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

  v_required := jsonb_build_object(
    'vehicle_plate', true,
    'terms_of_service', true,
    'indemnification_quiz', true
  );
  IF v_onboarding_v2 THEN
    IF v_completed >= 10 THEN
      v_required := v_required || jsonb_build_object(
        'rijbewijs_verified', true,
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
      AND v_plate_ok AND v_rijbewijs_ok
  );
END;
$$;
