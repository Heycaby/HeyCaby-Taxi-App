-- Correct enum-to-text handling in the risk-based readiness function.
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
  v_next_milestone int := 0;
  v_stage int := 0;
  v_review_account boolean := false;
  v_skip_gates boolean := false;
  v_flags jsonb := '{}'::jsonb;
  v_launch jsonb := '[]'::jsonb;
  v_launch_blockers jsonb := '[]'::jsonb;
  v_completed_requirements jsonb := '[]'::jsonb;
  v_optional jsonb := jsonb_build_array(
    'kvk_number', 'kvk_address', 'chauffeurspas',
    'taxi_insurance', 'driving_licence', 'identity_verification'
  );
  v_review public.driver_verification_reviews%ROWTYPE;
  v_review_requirements jsonb := '[]'::jsonb;
  v_review_blockers jsonb := '[]'::jsonb;
  v_item jsonb;
  v_doc text;
  v_complete boolean;
  v_label text;
  v_action text;
  v_profile_photo_ok boolean;
  v_vehicle_photo_ok boolean;
  v_terms_ok boolean;
  v_quiz_ok boolean;
  v_plate_ok boolean;
  v_tariff_ok boolean;
  v_can_go_online boolean;
  v_review_restricts boolean := false;
BEGIN
  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_go_online', false,
      'launch_requirements', '[]'::jsonb,
      'launch_blockers', '[]'::jsonb,
      'review_status', 'none',
      'review_blockers', '[]'::jsonb,
      'checklist', '[]'::jsonb,
      'missing_docs', '[]'::jsonb,
      'status_message', 'Driver not found',
      'completed_rides', 0
    );
  END IF;

  v_flags := public.fn_app_config_jsonb('feature_flags');
  v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);
  v_review_account := public.fn_driver_is_review_account(v_d.user_id);
  v_completed := public.fn_driver_lifetime_completed_rides(p_driver_id);

  -- Ride milestones remain available to analytics, but never affect readiness.
  v_next_milestone := CASE
    WHEN v_completed < 10 THEN 10
    WHEN v_completed < 50 THEN 50
    WHEN v_completed < 100 THEN 100
    ELSE 0
  END;
  v_stage := CASE
    WHEN v_completed < 10 THEN 0
    WHEN v_completed < 50 THEN 1
    WHEN v_completed < 100 THEN 2
    ELSE 3
  END;

  v_profile_photo_ok := length(trim(COALESCE(v_d.profile_photo_url, ''))) > 0;
  v_vehicle_photo_ok := EXISTS (
    SELECT 1
    FROM unnest(COALESCE(v_d.vehicle_photo_urls, ARRAY[]::text[])) u(url)
    WHERE length(trim(url)) > 0
  );
  v_terms_ok := v_d.terms_accepted_at IS NOT NULL;
  v_quiz_ok := v_d.indemnification_read_at IS NOT NULL
    AND COALESCE(v_d.indemnification_quiz_passed, false);
  v_plate_ok := length(trim(COALESCE(v_d.vehicle_plate, ''))) > 0
    AND (
      COALESCE(v_d.vehicle_verified, false)
      OR lower(COALESCE(v_d.vehicle_verification_status::text, '')) = 'rdw_verified_taxi'
    );
  v_tariff_ok := public.fn_driver_has_initial_tariff(p_driver_id);

  v_launch := jsonb_build_array(
    jsonb_build_object('key','vehicle_plate','label','Verify your taxi plate','complete',v_plate_ok,'action','/driver/onboarding/plate','priority',1),
    jsonb_build_object('key','terms_of_service','label','Accept the driver terms','complete',v_terms_ok,'action','/driver/terms','priority',2),
    jsonb_build_object('key','indemnification_quiz','label','Complete the platform responsibility quiz','complete',v_quiz_ok,'action','/driver/indemnification','priority',3),
    jsonb_build_object('key','profile_photo','label','Add your driver photo','complete',v_profile_photo_ok,'action','/driver/me?action=profile_photo&return=1','priority',4),
    jsonb_build_object('key','vehicle_photos','label','Add a photo of your taxi','complete',v_vehicle_photo_ok,'action','/driver/me?action=vehicle_photo&return=1','priority',5),
    jsonb_build_object('key','initial_tariff','label','Set your first tariff','complete',v_tariff_ok,'action','/driver/tariffs','priority',6)
  );

  SELECT * INTO v_review
  FROM public.driver_verification_reviews r
  WHERE r.driver_id = p_driver_id
    AND r.status IN ('requested', 'under_review', 'restricted')
  ORDER BY r.requested_at DESC
  LIMIT 1;

  IF FOUND THEN
    FOREACH v_doc IN ARRAY v_review.requested_docs LOOP
      v_complete := CASE v_doc
        WHEN 'driving_licence' THEN COALESCE(v_d.rijbewijs_verified, false)
        WHEN 'rijbewijs_verified' THEN COALESCE(v_d.rijbewijs_verified, false)
        WHEN 'chauffeurspas' THEN COALESCE(v_d.chauffeurspas_verified, false)
          OR (length(trim(COALESCE(v_d.chauffeurspas_number, ''))) > 0 AND v_d.chauffeurspas_expiry IS NOT NULL)
        WHEN 'taxi_insurance' THEN COALESCE(v_d.taxi_insurance_verified, false)
          OR (length(trim(COALESCE(v_d.taxi_insurance_photo_url, ''))) > 0 AND v_d.taxi_insurance_expiry IS NOT NULL)
        WHEN 'kvk_number' THEN length(trim(COALESCE(v_d.kvk_number, ''))) > 0
        WHEN 'kvk_address' THEN length(trim(COALESCE(v_d.kvk_address, ''))) > 0
        WHEN 'identity_verification' THEN lower(COALESCE(v_d.veriff_status, '')) IN ('approved', 'verified')
        WHEN 'vehicle_plate' THEN v_plate_ok
        WHEN 'vehicle_photos' THEN v_vehicle_photo_ok
        WHEN 'profile_photo' THEN v_profile_photo_ok
        ELSE false
      END;
      v_label := CASE v_doc
        WHEN 'driving_licence' THEN 'Upload your driving licence'
        WHEN 'rijbewijs_verified' THEN 'Verify your driving licence'
        WHEN 'chauffeurspas' THEN 'Upload your chauffeur card'
        WHEN 'taxi_insurance' THEN 'Upload your taxi insurance'
        WHEN 'kvk_number' THEN 'Add your KVK number'
        WHEN 'kvk_address' THEN 'Add your business address'
        WHEN 'identity_verification' THEN 'Complete identity verification'
        WHEN 'vehicle_plate' THEN 'Verify your taxi plate'
        WHEN 'vehicle_photos' THEN 'Add a photo of your taxi'
        WHEN 'profile_photo' THEN 'Add your driver photo'
        ELSE 'Provide the requested information'
      END;
      v_action := CASE v_doc
        WHEN 'driving_licence' THEN '/driver/veriff'
        WHEN 'rijbewijs_verified' THEN '/driver/veriff'
        WHEN 'identity_verification' THEN '/driver/veriff'
        WHEN 'vehicle_plate' THEN '/driver/onboarding/plate'
        WHEN 'vehicle_photos' THEN '/driver/me?action=vehicle_photo&return=1'
        WHEN 'profile_photo' THEN '/driver/me?action=profile_photo&return=1'
        ELSE '/driver/documents'
      END;
      v_item := jsonb_build_object(
        'key', v_doc,
        'label', v_label,
        'complete', v_complete,
        'action', v_action
      );
      v_review_requirements := v_review_requirements || jsonb_build_array(v_item);
      IF NOT v_complete THEN
        v_review_blockers := v_review_blockers || jsonb_build_array(v_item);
      END IF;
    END LOOP;
    v_review_restricts := v_review.restrict_online;
  END IF;

  SELECT COALESCE(jsonb_agg(value), '[]'::jsonb)
  INTO v_launch_blockers
  FROM jsonb_array_elements(v_launch)
  WHERE COALESCE((value->>'complete')::boolean, false) IS NOT TRUE;

  SELECT COALESCE(jsonb_agg(value->'key'), '[]'::jsonb)
  INTO v_completed_requirements
  FROM jsonb_array_elements(v_launch)
  WHERE COALESCE((value->>'complete')::boolean, false) IS TRUE;

  v_can_go_online := jsonb_array_length(v_launch_blockers) = 0
    AND NOT v_review_restricts;

  IF v_review_account OR v_skip_gates THEN
    v_can_go_online := true;
  END IF;

  RETURN jsonb_build_object(
    'can_go_online', v_can_go_online,
    'gates_skipped', v_review_account OR v_skip_gates,
    'launch_requirements', v_launch,
    'launch_blockers', v_launch_blockers,
    'completed_requirements', v_completed_requirements,
    'review_status', CASE WHEN v_review.id IS NULL THEN 'none' ELSE v_review.status END,
    'review_reason', CASE WHEN v_review.id IS NULL THEN NULL ELSE v_review.reason END,
    'review_restricts_online', v_review_restricts,
    'review_requirements', v_review_requirements,
    'review_blockers', v_review_blockers,
    'optional_profile_items', v_optional,
    -- Backwards compatibility for existing runtime and handover callers.
    'checklist', v_launch || v_review_requirements,
    'missing_docs', (
      SELECT COALESCE(jsonb_agg(value->'key'), '[]'::jsonb)
      FROM jsonb_array_elements(v_launch_blockers || v_review_blockers)
    ),
    'status_message', CASE
      WHEN v_review_account OR v_skip_gates THEN 'Readiness gates bypassed'
      WHEN jsonb_array_length(v_launch_blockers) > 0 THEN 'Complete your launch setup'
      WHEN v_review_restricts THEN 'Additional verification required'
      ELSE 'Ready to go online'
    END,
    'compliance_type', lower(COALESCE(v_d.country_code, 'NL')),
    'completed_rides', v_completed,
    'next_milestone_at', v_next_milestone,
    'onboarding_v2_stage', v_stage,
    'verification_required', v_review_restricts,
    'premium_eligible', v_completed >= 100
  );
END;
$$;
