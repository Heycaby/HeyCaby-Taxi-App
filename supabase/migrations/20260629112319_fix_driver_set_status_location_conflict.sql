-- Fix driver status-transition location upsert to match driver_locations' real
-- unique key. Break, online, and offline transitions share fn_driver_set_status;
-- when lat/lng is provided, using ON CONFLICT (driver_id) raises 42P10 because
-- the table is keyed by user_id.

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
      RETURN jsonb_build_object(
        'status', 'offline',
        'blocked_reason', 'missing_docs',
        'message', COALESCE(v_readiness->>'status_message', 'Compliance incomplete'),
        'readiness', v_readiness
      );
    END IF;

    v_flags := public.fn_app_config_jsonb('feature_flags');
    v_skip_gates := COALESCE((v_flags->>'skip_go_online_gates')::boolean, false);

    IF NOT v_skip_gates AND NOT public.fn_driver_is_review_account(v_user_id) THEN
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

REVOKE ALL ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_set_status(text, double precision, double precision) TO authenticated;
