-- Guest riders: bind device rider_token to auth.uid() in rider_sessions so
-- fn_rider_rate_driver (and other token RPCs) authorize without fragile client state.

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
    user_id = COALESCE(public.rider_sessions.user_id, EXCLUDED.user_id),
    last_active_at = timezone('utc', now());

  RETURN jsonb_build_object('ok', true, 'session_token', v_token);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_bind_session_token(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_bind_session_token(text) TO anon, authenticated;

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
  v_authorized boolean := false;
  v_token text := NULLIF(btrim(COALESCE(p_rider_token, '')), '');
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

  IF v_ride.rider_identity_id IS NOT NULL
     AND auth.uid() IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_identities ri
       WHERE ri.id = v_ride.rider_identity_id
         AND ri.user_id = auth.uid()
     ) THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized
     AND v_token IS NOT NULL
     AND v_ride.rider_token IS NOT NULL
     AND v_ride.rider_token = v_token THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized
     AND auth.uid() IS NOT NULL
     AND v_ride.rider_token IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_sessions rs
       WHERE rs.user_id = auth.uid()
         AND rs.session_token IS NOT NULL
         AND btrim(rs.session_token) <> ''
         AND rs.session_token = v_ride.rider_token
     ) THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized THEN
    RETURN json_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  IF v_ride.rider_token IS NULL OR btrim(v_ride.rider_token) = '' THEN
    RETURN json_build_object('ok', false, 'error', 'missing_rider_token');
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
    v_ride.rider_token,
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

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'driver_id', v_ride.driver_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) TO anon, authenticated;
