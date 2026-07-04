-- Enforce the core live-marketplace rule:
-- no GPS coordinates means no driver availability, and rider bookings with a
-- known identity must have a current app-side location permission sync.

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
    IF p_lat IS NULL
       OR p_lng IS NULL
       OR p_lat < -90
       OR p_lat > 90
       OR p_lng < -180
       OR p_lng > 180 THEN
      RETURN jsonb_build_object(
        'status', 'offline',
        'blocked_reason', 'location_required',
        'message', 'Turn on location before going online.'
      );
    END IF;

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
      PERFORM public.fn_driver_platform_balance_ensure_weekly(v_driver_id);
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

COMMENT ON FUNCTION public.fn_driver_set_status(text, double precision, double precision)
  IS 'Driver availability mutation. Going available requires valid GPS coordinates so offline/no-location drivers cannot enter live matching.';

CREATE OR REPLACE FUNCTION public.trg_require_rider_location_permission_for_booking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_location_granted boolean;
BEGIN
  IF NEW.rider_identity_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.status, '') IN ('pending', 'bidding') THEN
    SELECT ri.app_location_permission_granted
    INTO v_location_granted
    FROM public.rider_identities ri
    WHERE ri.id = NEW.rider_identity_id;

    IF COALESCE(v_location_granted, false) IS NOT TRUE THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = 'Location permission is required to book rides.',
        DETAIL = 'rider_location_required';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_require_rider_location_permission_for_booking
  ON public.ride_requests;

CREATE TRIGGER trg_require_rider_location_permission_for_booking
  BEFORE INSERT OR UPDATE OF status, rider_identity_id
  ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_require_rider_location_permission_for_booking();

REVOKE ALL ON FUNCTION public.trg_require_rider_location_permission_for_booking() FROM PUBLIC;

COMMENT ON FUNCTION public.trg_require_rider_location_permission_for_booking()
  IS 'Blocks rider bookings for known rider identities when the app has not synced active location permission.';
