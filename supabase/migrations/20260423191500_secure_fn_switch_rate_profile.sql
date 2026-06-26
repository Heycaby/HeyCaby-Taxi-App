-- Harden tariff switching to authenticated driver's own profile only.

CREATE OR REPLACE FUNCTION public.fn_switch_rate_profile(
  p_driver_id uuid,
  p_profile_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_profile RECORD;
  v_auth_driver_id uuid;
BEGIN
  -- Enforce ownership from auth context (prevents switching another driver's tariff).
  SELECT d.id
  INTO v_auth_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_auth_driver_id IS NULL OR v_auth_driver_id <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  -- Get selected profile for that same authenticated driver.
  SELECT *
  INTO v_profile
  FROM public.driver_rate_profiles
  WHERE id = p_profile_id
    AND driver_id = p_driver_id;

  IF v_profile IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'profile_not_found');
  END IF;

  -- Deactivate all profiles for this driver.
  UPDATE public.driver_rate_profiles
  SET is_active = false,
      updated_at = now()
  WHERE driver_id = p_driver_id;

  -- Activate selected profile.
  UPDATE public.driver_rate_profiles
  SET is_active = true,
      updated_at = now()
  WHERE id = p_profile_id
    AND driver_id = p_driver_id;

  -- Keep live matching prices in drivers table in sync.
  UPDATE public.drivers
  SET base_fare = v_profile.base_fare,
      per_km_rate = v_profile.per_km_rate,
      per_min_rate = v_profile.per_min_rate,
      minimum_fare = v_profile.minimum_fare,
      waiting_time_rate_per_min = v_profile.waiting_rate,
      updated_at = now()
  WHERE id = p_driver_id;

  RETURN jsonb_build_object(
    'success', true,
    'profile_id', p_profile_id,
    'profile_name', v_profile.profile_name,
    'base_fare', v_profile.base_fare,
    'per_km_rate', v_profile.per_km_rate,
    'per_min_rate', v_profile.per_min_rate,
    'waiting_rate', v_profile.waiting_rate
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_switch_rate_profile(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_switch_rate_profile(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_switch_rate_profile(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_switch_rate_profile(uuid, uuid) TO service_role;
