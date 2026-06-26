-- Fix rider push registration when legacy rider_identities.user_id is NULL.
-- 1) Backfill user_id by matching rider_identities.email to auth.users.email.
-- 2) Relax fn_register_push_device ownership check for rider role:
--    allow p_rider_identity_id when row user_id is NULL but email matches auth user.

UPDATE public.rider_identities ri
SET user_id = au.id
FROM auth.users au
WHERE ri.user_id IS NULL
  AND ri.email IS NOT NULL
  AND lower(trim(ri.email)) = lower(trim(au.email));

CREATE OR REPLACE FUNCTION public.fn_register_push_device(
  p_fcm_token text,
  p_platform text,
  p_app_role text,
  p_rider_identity_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver_id uuid;
  v_auth_email text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_fcm_token IS NULL OR length(trim(p_fcm_token)) < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_token');
  END IF;

  IF p_platform NOT IN ('ios', 'android') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_platform');
  END IF;

  IF p_app_role NOT IN ('rider', 'driver') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_app_role');
  END IF;

  IF p_app_role = 'driver' THEN
    SELECT id INTO v_driver_id FROM public.drivers WHERE user_id = v_uid LIMIT 1;
    IF v_driver_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
    END IF;

    INSERT INTO public.push_devices (
      fcm_token, platform, app_role, driver_id, auth_user_id
    )
    VALUES (
      trim(p_fcm_token), p_platform, 'driver', v_driver_id, v_uid
    )
    ON CONFLICT (fcm_token) DO UPDATE SET
      driver_id = EXCLUDED.driver_id,
      auth_user_id = EXCLUDED.auth_user_id,
      platform = EXCLUDED.platform,
      app_role = 'driver',
      rider_identity_id = NULL,
      updated_at = now();

    RETURN jsonb_build_object('success', true);
  END IF;

  IF p_rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'rider_identity_required');
  END IF;

  SELECT u.email INTO v_auth_email FROM auth.users u WHERE u.id = v_uid LIMIT 1;

  IF NOT EXISTS (
    SELECT 1
    FROM public.rider_identities ri
    WHERE ri.id = p_rider_identity_id
      AND (
        ri.user_id = v_uid
        OR (
          ri.user_id IS NULL
          AND v_auth_email IS NOT NULL
          AND ri.email IS NOT NULL
          AND lower(trim(ri.email)) = lower(trim(v_auth_email))
        )
      )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'identity_mismatch');
  END IF;

  INSERT INTO public.push_devices (
    fcm_token, platform, app_role, rider_identity_id, auth_user_id
  )
  VALUES (
    trim(p_fcm_token), p_platform, 'rider', p_rider_identity_id, v_uid
  )
  ON CONFLICT (fcm_token) DO UPDATE SET
    rider_identity_id = EXCLUDED.rider_identity_id,
    auth_user_id = EXCLUDED.auth_user_id,
    platform = EXCLUDED.platform,
    app_role = 'rider',
    driver_id = NULL,
    updated_at = now();

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_register_push_device (text, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_register_push_device (text, text, text, uuid) TO authenticated;
