-- Rider rate driver: robust auth for guest identities + token fetch RPC.

DROP FUNCTION IF EXISTS public.fn_rider_fetch_ride_token(uuid);

CREATE OR REPLACE FUNCTION public.fn_rider_bind_session_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text := NULLIF(btrim(COALESCE(p_token, '')), '');
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  IF v_token IS NULL OR char_length(v_token) <> 36 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_token');
  END IF;

  INSERT INTO public.rider_sessions (
    session_token,
    user_id,
    created_at,
    last_active_at
  )
  VALUES (
    v_token,
    v_uid,
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (session_token) DO UPDATE
  SET
    user_id = EXCLUDED.user_id,
    last_active_at = timezone('utc', now());

  RETURN jsonb_build_object('ok', true, 'session_token', v_token);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_assert_ride_access(
  p_ride_id uuid,
  p_hint_token text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_hint text := NULLIF(btrim(COALESCE(p_hint_token, '')), '');
  v_ride_token text;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_ride_token := NULLIF(btrim(v_ride.rider_token), '');
  IF v_ride_token IS NULL THEN
    RETURN false;
  END IF;

  IF v_ride.rider_identity_id IS NOT NULL
     AND auth.uid() IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_identities ri
       WHERE ri.id = v_ride.rider_identity_id
         AND ri.user_id = auth.uid()
     ) THEN
    RETURN true;
  END IF;

  IF v_hint IS NOT NULL AND v_ride_token = v_hint THEN
    RETURN true;
  END IF;

  IF auth.uid() IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
        AND btrim(rs.session_token) = v_ride_token
    ) THEN
      RETURN true;
    END IF;

    IF v_ride.rider_identity_id IS NOT NULL
       AND EXISTS (
         SELECT 1
         FROM public.push_devices pd
         WHERE pd.auth_user_id = auth.uid()
           AND pd.app_role = 'rider'
           AND pd.rider_identity_id = v_ride.rider_identity_id
       ) THEN
      RETURN true;
    END IF;

    IF v_ride.rider_identity_id IS NOT NULL
       AND EXISTS (
         SELECT 1
         FROM public.rider_identities ri
         JOIN auth.users au ON au.id = auth.uid()
         WHERE ri.id = v_ride.rider_identity_id
           AND ri.email IS NOT NULL
           AND btrim(ri.email) <> ''
           AND lower(btrim(ri.email)) = lower(btrim(au.email::text))
       ) THEN
      RETURN true;
    END IF;
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_fetch_ride_token(
  p_ride_id uuid,
  p_hint_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride_token text;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  IF NOT public.fn_rider_assert_ride_access(p_ride_id, p_hint_token) THEN
    IF auth.uid() IS NULL AND NULLIF(btrim(COALESCE(p_hint_token, '')), '') IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
    END IF;
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  SELECT NULLIF(btrim(rr.rider_token), '') INTO v_ride_token
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_id;

  IF v_ride_token IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_rider_token');
  END IF;

  IF auth.uid() IS NOT NULL THEN
    PERFORM public.fn_rider_bind_session_token(v_ride_token);
  END IF;

  RETURN jsonb_build_object('ok', true, 'rider_token', v_ride_token);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_rate_driver(
  p_ride_request_id uuid,
  p_rating smallint,
  p_comment text DEFAULT NULL,
  p_rider_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_comment text;
  v_hint text := NULLIF(btrim(COALESCE(p_rider_token, '')), '');
  v_ride_token text;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_rating');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'completed'
    AND rr.driver_id IS NOT NULL;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  v_ride_token := NULLIF(btrim(v_ride.rider_token), '');
  IF v_ride_token IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_rider_token');
  END IF;

  IF NOT public.fn_rider_assert_ride_access(p_ride_request_id, v_hint) THEN
    RETURN json_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  IF auth.uid() IS NOT NULL THEN
    PERFORM public.fn_rider_bind_session_token(v_ride_token);
  END IF;

  v_comment := NULLIF(btrim(COALESCE(p_comment, '')), '');
  IF v_comment IS NOT NULL AND char_length(v_comment) > 100 THEN
    v_comment := left(v_comment, 100);
  END IF;

  INSERT INTO public.ride_ratings (
    ride_request_id,
    driver_id,
    rider_token,
    rider_rating_of_driver,
    punctuality,
    cleanliness,
    attitude,
    driving_safety,
    communication,
    rider_rated_at,
    rider_comment
  )
  VALUES (
    p_ride_request_id,
    v_ride.driver_id,
    v_ride_token,
    p_rating,
    p_rating,
    p_rating,
    p_rating,
    p_rating,
    p_rating,
    timezone('utc', now()),
    v_comment
  )
  ON CONFLICT (ride_request_id) DO UPDATE
  SET
    rider_rating_of_driver = EXCLUDED.rider_rating_of_driver,
    punctuality = EXCLUDED.punctuality,
    cleanliness = EXCLUDED.cleanliness,
    attitude = EXCLUDED.attitude,
    driving_safety = EXCLUDED.driving_safety,
    communication = EXCLUDED.communication,
    rider_rated_at = EXCLUDED.rider_rated_at,
    rider_comment = COALESCE(EXCLUDED.rider_comment, public.ride_ratings.rider_comment);

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'trip.rated_by_rider',
    NULL,
    jsonb_build_object('rating', p_rating, 'driver_id', v_ride.driver_id),
    'rider',
    'rpc',
    p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'driver_id', v_ride.driver_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_assert_ride_access(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_rider_fetch_ride_token(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_rider_bind_session_token(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_rider_assert_ride_access(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_rider_fetch_ride_token(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_bind_session_token(text) TO anon, authenticated;
