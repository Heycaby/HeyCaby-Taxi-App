-- Rider rates driver after completed trip (session-token aware; bypasses ride_ratings RLS).

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
     AND p_rider_token IS NOT NULL
     AND btrim(p_rider_token) <> ''
     AND v_ride.rider_token = btrim(p_rider_token) THEN
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
GRANT EXECUTE ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) IS
  'Rider rates assigned driver after completed trip; authorizes via rider_token or identity.';

-- Allow favorites when ride has session token but no rider_identity_id on the row.
CREATE OR REPLACE FUNCTION public.fn_rider_add_favorite_driver(
  p_ride_request_id uuid,
  p_driver_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ride            public.ride_requests%ROWTYPE;
  v_rider_identity_id uuid;
  v_rating_id       uuid;
  v_rating_value    smallint;
  v_active_count    integer;
  v_existing        uuid;
  v_new_id          uuid;
  v_auth_ok         boolean := false;
  v_rider_name      text;
  v_notif_body      text;
  v_notif_id        uuid;
  v_agent_url       text;
  v_agent_secret    text;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;

  v_rider_identity_id := v_ride.rider_identity_id;

  IF v_rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_rider_identity_id AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
  END IF;

  IF NOT v_auth_ok
     AND p_rider_token IS NOT NULL
     AND btrim(p_rider_token) <> ''
     AND v_ride.rider_token = btrim(p_rider_token) THEN
    v_auth_ok := true;
  END IF;

  IF NOT v_auth_ok
     AND auth.uid() IS NOT NULL
     AND v_ride.rider_token IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_sessions rs
       WHERE rs.user_id = auth.uid()
         AND rs.session_token = v_ride.rider_token
     ) THEN
    v_auth_ok := true;
  END IF;

  IF NOT v_auth_ok THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authorized');
  END IF;

  IF v_rider_identity_id IS NULL AND auth.uid() IS NOT NULL THEN
    SELECT id INTO v_rider_identity_id
    FROM public.rider_identities
    WHERE user_id = auth.uid()
    ORDER BY created_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  IF v_rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rider_identity');
  END IF;

  IF v_ride.status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_completed');
  END IF;

  IF v_ride.driver_id IS NULL OR v_ride.driver_id <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_mismatch');
  END IF;

  SELECT id, rider_rating_of_driver
  INTO v_rating_id, v_rating_value
  FROM public.ride_ratings
  WHERE ride_request_id = p_ride_request_id
    AND rider_rating_of_driver IS NOT NULL
  LIMIT 1;

  IF v_rating_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rating');
  END IF;

  IF v_rating_value < 4 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'rating_below_threshold');
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = v_rider_identity_id
    AND is_active = true;

  IF v_active_count >= 10 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'favorite_limit_reached');
  END IF;

  SELECT id INTO v_existing
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = v_rider_identity_id
    AND driver_id = p_driver_id
    AND is_active = true;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_favorited', 'favorite_id', v_existing);
  END IF;

  INSERT INTO public.rider_favorite_drivers (
    rider_identity_id,
    driver_id,
    source_ride_request_id,
    rating_id,
    is_active
  ) VALUES (
    v_rider_identity_id,
    p_driver_id,
    p_ride_request_id,
    v_rating_id,
    true
  )
  RETURNING id INTO v_new_id;

  SELECT COALESCE(booking_name, split_part(email, '@', 1))
  INTO v_rider_name
  FROM public.rider_identities
  WHERE id = v_rider_identity_id;

  v_rider_name := split_part(COALESCE(v_rider_name, 'A rider'), ' ', 1);

  IF v_rating_value = 5 THEN
    v_notif_body := v_rider_name || ' rated you 5 stars and added you as a Favorite Driver.';
  ELSIF v_rating_value = 4 THEN
    v_notif_body := v_rider_name || ' rated you 4 stars and added you as a Favorite Driver.';
  ELSE
    v_notif_body := v_rider_name || ' added you as a Favorite Driver.';
  END IF;

  INSERT INTO public.notifications (
    user_type,
    user_id,
    agent,
    category,
    title,
    body,
    data,
    priority,
    channel
  ) VALUES (
    'driver',
    p_driver_id::text,
    'driver_agent',
    'favorite_added',
    'New Favorite',
    v_notif_body,
    jsonb_build_object(
      'favorite_id', v_new_id,
      'ride_request_id', p_ride_request_id,
      'rating', v_rating_value
    ),
    'medium',
    'both'
  )
  RETURNING id INTO v_notif_id;

  INSERT INTO public.ride_audit_log (
    ride_id,
    event,
    actor_id,
    actor_type,
    occurred_at,
    metadata,
    source
  ) VALUES (
    p_ride_request_id,
    'favorite_driver.added',
    v_rider_identity_id,
    'rider',
    now(),
    jsonb_build_object(
      'rider_id', v_rider_identity_id,
      'driver_id', p_driver_id,
      'ride_request_id', p_ride_request_id,
      'rating', v_rating_value,
      'favorite_id', v_new_id
    ),
    'fn_rider_add_favorite_driver'
  );

  SELECT value INTO v_agent_url FROM public.app_config WHERE key = 'agent_webhook_url' LIMIT 1;
  SELECT value INTO v_agent_secret FROM public.app_config WHERE key = 'agent_webhook_secret' LIMIT 1;

  IF v_agent_url IS NOT NULL AND length(trim(v_agent_url)) > 0 THEN
    PERFORM net.http_post(
      url := trim(v_agent_url),
      body := jsonb_build_object(
        'event', 'favorite_added',
        'notification_id', v_notif_id,
        'driver_id', p_driver_id,
        'title', 'New Favorite',
        'body', v_notif_body,
        'data', jsonb_build_object(
          'favorite_id', v_new_id,
          'ride_request_id', p_ride_request_id,
          'rating', v_rating_value
        ),
        'priority', 'medium'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', COALESCE(v_agent_secret, '')
      ),
      timeout_milliseconds := 5000
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'favorite_id', v_new_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_rider_add_favorite_driver(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_add_favorite_driver(uuid, uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.fn_rider_add_favorite_driver(uuid, uuid);
