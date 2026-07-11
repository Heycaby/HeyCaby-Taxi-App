-- Driver activation is based on the six launch requirements. Ride-count
-- milestones remain analytics only. Deeper documents are requested through
-- an explicit, auditable review case.

CREATE TABLE IF NOT EXISTS public.driver_verification_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'under_review', 'cleared', 'restricted')),
  reason text NOT NULL,
  requested_docs text[] NOT NULL DEFAULT ARRAY[]::text[],
  restrict_online boolean NOT NULL DEFAULT true,
  requested_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  deadline_at timestamptz,
  completed_at timestamptz,
  requested_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  decision_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS driver_verification_reviews_driver_status_idx
  ON public.driver_verification_reviews(driver_id, status, requested_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS driver_verification_reviews_one_active_idx
  ON public.driver_verification_reviews(driver_id)
  WHERE status IN ('requested', 'under_review', 'restricted');

ALTER TABLE public.driver_verification_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_verification_reviews_select_own
  ON public.driver_verification_reviews;
CREATE POLICY driver_verification_reviews_select_own
  ON public.driver_verification_reviews
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.drivers d
      WHERE d.id = driver_verification_reviews.driver_id
        AND d.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS driver_verification_reviews_admin_all
  ON public.driver_verification_reviews;
CREATE POLICY driver_verification_reviews_admin_all
  ON public.driver_verification_reviews
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = (SELECT auth.uid())
    )
  );

CREATE TABLE IF NOT EXISTS public.driver_verification_review_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL
    REFERENCES public.driver_verification_reviews(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  previous_status text,
  new_status text,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS driver_verification_review_events_review_idx
  ON public.driver_verification_review_events(review_id, created_at DESC);

ALTER TABLE public.driver_verification_review_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_verification_review_events_admin_select
  ON public.driver_verification_review_events;
CREATE POLICY driver_verification_review_events_admin_select
  ON public.driver_verification_review_events
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = (SELECT auth.uid())
    )
  );

CREATE OR REPLACE FUNCTION public.fn_audit_driver_verification_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.driver_verification_review_events (
    review_id,
    driver_id,
    event_type,
    previous_status,
    new_status,
    actor_id,
    details
  ) VALUES (
    NEW.id,
    NEW.driver_id,
    CASE WHEN TG_OP = 'INSERT' THEN 'review_requested' ELSE 'review_updated' END,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.status ELSE NULL END,
    NEW.status,
    auth.uid(),
    jsonb_build_object(
      'reason', NEW.reason,
      'requested_docs', to_jsonb(NEW.requested_docs),
      'deadline_at', NEW.deadline_at,
      'restrict_online', NEW.restrict_online,
      'decision_notes', NEW.decision_notes
    )
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_touch_driver_verification_review()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  IF NEW.status = 'cleared' AND NEW.completed_at IS NULL THEN
    NEW.completed_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_driver_verification_review
  ON public.driver_verification_reviews;
CREATE TRIGGER trg_touch_driver_verification_review
BEFORE UPDATE ON public.driver_verification_reviews
FOR EACH ROW EXECUTE FUNCTION public.fn_touch_driver_verification_review();

DROP TRIGGER IF EXISTS trg_audit_driver_verification_review
  ON public.driver_verification_reviews;
CREATE TRIGGER trg_audit_driver_verification_review
AFTER INSERT OR UPDATE ON public.driver_verification_reviews
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_driver_verification_review();

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

COMMENT ON TABLE public.driver_verification_reviews IS
  'Explicit, reasoned driver verification reviews. Ride count never creates a review.';
COMMENT ON FUNCTION public.fn_driver_readiness_eval(uuid) IS
  'Server-owned launch readiness plus explicit risk-review blockers; ride milestones are analytics only.';

REVOKE ALL ON TABLE public.driver_verification_reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.driver_verification_reviews TO authenticated;
GRANT ALL ON TABLE public.driver_verification_reviews TO service_role;

REVOKE ALL ON TABLE public.driver_verification_review_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.driver_verification_review_events TO authenticated;
GRANT ALL ON TABLE public.driver_verification_review_events TO service_role;

REVOKE ALL ON FUNCTION public.fn_audit_driver_verification_review() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_audit_driver_verification_review() TO service_role;
REVOKE ALL ON FUNCTION public.fn_touch_driver_verification_review() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_touch_driver_verification_review() TO service_role;

-- These are internal helpers called by authenticated, owner-validating RPCs.
REVOKE ALL ON FUNCTION public.fn_driver_readiness_eval(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_readiness_eval(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_runtime_permissions(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_runtime_permissions(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_requester_snapshot(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_requester_snapshot(uuid)
  TO service_role;

-- The app uses the five-argument step-up protected handover RPC. Retire the
-- legacy overload from client access and remove anonymous access from both.
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid)
  TO authenticated, service_role;

-- Tariff readiness is internal; clients use runtime and tariff CRUD paths.
REVOKE ALL ON FUNCTION public.fn_driver_has_initial_tariff(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_has_initial_tariff(uuid) TO service_role;
