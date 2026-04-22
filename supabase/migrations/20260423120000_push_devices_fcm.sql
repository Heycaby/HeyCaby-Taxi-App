-- P0: FCM-only push delivery — multi-device [push_devices], RPC registration.
-- Expo / legacy single-column driver token path removed from application code (use this table only).

CREATE TABLE IF NOT EXISTS public.push_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fcm_token text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('ios', 'android')),
  app_role text NOT NULL CHECK (app_role IN ('rider', 'driver')),
  rider_identity_id uuid REFERENCES public.rider_identities (id) ON DELETE CASCADE,
  driver_id uuid REFERENCES public.drivers (id) ON DELETE CASCADE,
  auth_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT push_devices_target_chk CHECK (
    (
      app_role = 'rider'
      AND rider_identity_id IS NOT NULL
      AND driver_id IS NULL
    )
    OR (
      app_role = 'driver'
      AND driver_id IS NOT NULL
      AND rider_identity_id IS NULL
    )
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS push_devices_fcm_token_key ON public.push_devices (fcm_token);

CREATE INDEX IF NOT EXISTS push_devices_rider_ix ON public.push_devices (rider_identity_id)
  WHERE rider_identity_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS push_devices_driver_ix ON public.push_devices (driver_id)
  WHERE driver_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS push_devices_auth_user_ix ON public.push_devices (auth_user_id);

COMMENT ON TABLE public.push_devices IS
  'FCM device tokens (HTTP v1). One row per token; users may have multiple devices.';

ALTER TABLE public.push_devices ENABLE ROW LEVEL SECURITY;

-- Direct PostgREST access disabled; clients use SECURITY DEFINER RPCs only.
DROP POLICY IF EXISTS push_devices_block_all ON public.push_devices;
CREATE POLICY push_devices_block_all ON public.push_devices
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);

-- Legacy column no longer used for delivery (FCM uses push_devices).
ALTER TABLE public.drivers DROP COLUMN IF EXISTS push_token;

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

  IF NOT EXISTS (
    SELECT 1
    FROM public.rider_identities ri
    WHERE ri.id = p_rider_identity_id
      AND ri.user_id = v_uid
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

CREATE OR REPLACE FUNCTION public.fn_unregister_all_my_push_devices(p_app_role text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_app_role IS NULL THEN
    DELETE FROM public.push_devices WHERE auth_user_id = v_uid;
  ELSE
    IF p_app_role NOT IN ('rider', 'driver') THEN
      RETURN jsonb_build_object('success', false, 'error', 'invalid_app_role');
    END IF;
    DELETE FROM public.push_devices
    WHERE auth_user_id = v_uid
      AND app_role = p_app_role;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_unregister_all_my_push_devices (text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_unregister_all_my_push_devices (text) TO authenticated;
