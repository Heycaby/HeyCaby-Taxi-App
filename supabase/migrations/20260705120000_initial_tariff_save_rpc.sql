-- Initial tariff save RPC + blueprint-aligned readiness check.
-- Fixes driver "Set your first tariff" sheet: clients must not write
-- driver_rate_profiles directly; use this SECURITY DEFINER RPC instead.
-- Minimum tariff = start fee, price/km, price/min, waiting rate (no VAT gate).

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
      AND rp.waiting_rate IS NOT NULL
      AND rp.waiting_rate >= 0
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_save_initial_tariff(
  p_base_fare numeric,
  p_per_km_rate numeric,
  p_per_min_rate numeric,
  p_waiting_rate numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_profile_id uuid;
  v_existing record;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_driver');
  END IF;

  IF p_base_fare IS NULL OR p_base_fare < 0
     OR p_per_km_rate IS NULL OR p_per_km_rate <= 0
     OR p_per_min_rate IS NULL OR p_per_min_rate < 0
     OR p_waiting_rate IS NULL OR p_waiting_rate < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amounts');
  END IF;

  SELECT id, profile_name INTO v_existing
  FROM public.driver_rate_profiles
  WHERE driver_id = v_driver_id
    AND COALESCE(is_active, false) IS TRUE
  ORDER BY sort_order NULLS LAST, created_at
  LIMIT 1;

  IF v_existing.id IS NOT NULL THEN
    v_profile_id := v_existing.id;
    UPDATE public.driver_rate_profiles
    SET base_fare = p_base_fare,
        per_km_rate = p_per_km_rate,
        per_min_rate = p_per_min_rate,
        waiting_rate = p_waiting_rate,
        minimum_fare = p_base_fare,
        updated_at = timezone('utc', now())
    WHERE id = v_profile_id
      AND driver_id = v_driver_id;
  ELSE
    INSERT INTO public.driver_rate_profiles (
      driver_id,
      profile_name,
      base_fare,
      per_km_rate,
      per_min_rate,
      minimum_fare,
      waiting_rate,
      is_active,
      sort_order
    ) VALUES (
      v_driver_id,
      'Standaard',
      p_base_fare,
      p_per_km_rate,
      p_per_min_rate,
      p_base_fare,
      p_waiting_rate,
      true,
      0
    )
    RETURNING id INTO v_profile_id;
  END IF;

  -- Keep drivers row in sync with the active tariff (dispatch + estimates).
  UPDATE public.drivers
  SET base_fare = p_base_fare,
      per_km_rate = p_per_km_rate,
      per_min_rate = p_per_min_rate,
      waiting_time_rate_per_min = p_waiting_rate,
      minimum_fare = p_base_fare,
      updated_at = timezone('utc', now())
  WHERE id = v_driver_id;

  IF to_regclass('public.driver_tariff_events') IS NOT NULL THEN
    INSERT INTO public.driver_tariff_events (driver_id, profile_id, event_type, payload)
    VALUES (
      v_driver_id,
      v_profile_id,
      'initial_tariff_saved',
      jsonb_build_object(
        'base_fare', p_base_fare,
        'per_km_rate', p_per_km_rate,
        'per_min_rate', p_per_min_rate,
        'waiting_rate', p_waiting_rate
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'profile_id', v_profile_id,
    'driver_id', v_driver_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_save_initial_tariff(numeric, numeric, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_save_initial_tariff(numeric, numeric, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_save_initial_tariff(numeric, numeric, numeric, numeric) TO service_role;

COMMENT ON FUNCTION public.fn_driver_save_initial_tariff(numeric, numeric, numeric, numeric) IS
  'Creates or updates the driver''s first active tariff (start fee, km, min, waiting). Used by the go-online tariff sheet.';
