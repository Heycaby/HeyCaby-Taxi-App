-- Ensure App Review driver bootstrap remains stable after rebranding and trigger changes.
-- - Uses app_config.apple_review_email instead of legacy hardcoded domain.
-- - Avoids tuple-conflict upsert pattern observed on drivers updates.

CREATE OR REPLACE FUNCTION public.setup_review_driver_profile(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_review_email text;
  v_driver_id uuid;
BEGIN
  SELECT value INTO v_review_email
  FROM public.app_config
  WHERE key = 'apple_review_email';

  v_review_email := COALESCE(NULLIF(trim(v_review_email), ''), 'review@heycaby.nl');

  INSERT INTO public.drivers (
    user_id, email, full_name,
    compliance_status, profile_status, is_verified_badge,
    chauffeurspas_verified, rijbewijs_verified,
    taxi_insurance_verified, kvk_verified, vehicle_verified,
    vehicle_plate, vehicle_make, vehicle_model,
    rdw_merk, rdw_handelsbenaming, vehicle_verification_status,
    avg_rating, rating,
    payment_methods,
    pickup_distance_max_km,
    personal_info_completed, vehicle_info_completed,
    congratulations_modal_shown, created_at, updated_at
  ) VALUES (
    p_user_id, v_review_email, 'Review Driver',
    'compliant', 'verified', true,
    true, true, true, true, true,
    'RL123B', 'Toyota', 'Prius',
    'TOYOTA', 'PRIUS', 'rdw_verified_taxi',
    4.9, 4.9,
    ARRAY['cash','card','tikkie']::payment_method[],
    20, true, true, true, now(), now()
  )
  ON CONFLICT (user_id) DO NOTHING;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = p_user_id
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_row_missing');
  END IF;

  INSERT INTO public.driver_onboarding_steps (
    driver_id,
    step_personal_done,
    step_business_done,
    step_vehicle_done,
    step_compliance_done,
    sub_chauffeurspas_done,
    sub_rijbewijs_done,
    sub_vog_done,
    sub_taxidiploma_done,
    sub_insurance_done,
    step_rates_done,
    step_legal_done,
    onboarding_completed_at,
    current_step,
    updated_at
  ) VALUES (
    v_driver_id,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    now(),
    999,
    now()
  )
  ON CONFLICT (driver_id) DO UPDATE SET
    step_personal_done = true,
    step_business_done = true,
    step_vehicle_done = true,
    step_compliance_done = true,
    sub_chauffeurspas_done = true,
    sub_rijbewijs_done = true,
    sub_vog_done = true,
    sub_taxidiploma_done = true,
    sub_insurance_done = true,
    step_rates_done = true,
    step_legal_done = true,
    onboarding_completed_at = COALESCE(public.driver_onboarding_steps.onboarding_completed_at, now()),
    current_step = GREATEST(COALESCE(public.driver_onboarding_steps.current_step, 0), 999),
    updated_at = now();

  INSERT INTO public.driver_trust_scores (driver_id, public_stars, trust_score)
  VALUES (v_driver_id, 4.9, 95.0)
  ON CONFLICT (driver_id) DO UPDATE SET
    public_stars = EXCLUDED.public_stars,
    trust_score = EXCLUDED.trust_score;

  RETURN jsonb_build_object('success', true, 'driver_id', v_driver_id);
END;
$$;
