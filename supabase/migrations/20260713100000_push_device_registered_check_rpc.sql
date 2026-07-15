-- Lets clients verify the current FCM token is registered in push_devices (not just local getToken).

CREATE OR REPLACE FUNCTION public.fn_is_push_device_registered(
  p_app_role text,
  p_fcm_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_registered boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('registered', false, 'error', 'not_authenticated');
  END IF;

  IF p_app_role NOT IN ('rider', 'driver') THEN
    RETURN jsonb_build_object('registered', false, 'error', 'invalid_app_role');
  END IF;

  IF p_fcm_token IS NULL OR length(trim(p_fcm_token)) < 10 THEN
    RETURN jsonb_build_object('registered', false);
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.push_devices pd
    WHERE pd.auth_user_id = v_uid
      AND pd.app_role = p_app_role
      AND pd.fcm_token = trim(p_fcm_token)
  ) INTO v_registered;

  RETURN jsonb_build_object('registered', v_registered);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_is_push_device_registered(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_is_push_device_registered(text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_is_push_device_registered(text, text) IS
  'Returns whether the signed-in user has the given FCM token registered for app_role in push_devices.';
