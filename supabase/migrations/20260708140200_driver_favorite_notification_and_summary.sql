-- ============================================================
-- 1. Update fn_rider_add_favorite_driver to also:
--    a) Insert a notification for the driver
--    b) Write an audit event to ride_audit_log
--    c) Trigger FCM push via driver-agent Edge Function (net.http_post)
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_rider_add_favorite_driver(
  p_ride_request_id uuid,
  p_driver_id uuid
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
  v_auth_ok         boolean;
  v_rider_name      text;
  v_notif_body      text;
  v_notif_id        uuid;
  v_agent_url       text;
  v_agent_secret    text;
BEGIN
  -- 1. Ride exists
  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;

  v_rider_identity_id := v_ride.rider_identity_id;

  IF v_rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rider_identity');
  END IF;

  -- 2. Auth check: if auth.uid() is available, verify ownership
  IF auth.uid() IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_rider_identity_id AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
    IF NOT v_auth_ok THEN
      RETURN jsonb_build_object('success', false, 'reason', 'not_authorized');
    END IF;
  END IF;

  -- 3. Ride is completed
  IF v_ride.status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_completed');
  END IF;

  -- 4. Driver was assigned to that ride
  IF v_ride.driver_id IS NULL OR v_ride.driver_id <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_mismatch');
  END IF;

  -- 5. Rating exists and meets threshold (>= 5)
  SELECT id, rider_rating_of_driver
  INTO v_rating_id, v_rating_value
  FROM public.ride_ratings
  WHERE ride_request_id = p_ride_request_id
    AND rider_rating_of_driver IS NOT NULL
  LIMIT 1;

  IF v_rating_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rating');
  END IF;

  IF v_rating_value < 5 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'rating_below_threshold');
  END IF;

  -- 6. Rider has fewer than 10 active favorites
  SELECT COUNT(*) INTO v_active_count
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = v_rider_identity_id
    AND is_active = true;

  IF v_active_count >= 10 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'favorite_limit_reached');
  END IF;

  -- 7. Driver is not already an active favorite
  SELECT id INTO v_existing
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = v_rider_identity_id
    AND driver_id = p_driver_id
    AND is_active = true;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_favorited', 'favorite_id', v_existing);
  END IF;

  -- 8. Insert favorite row
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

  -- 9. Get rider's first name for notification (privacy-safe)
  SELECT COALESCE(booking_name, split_part(email, '@', 1))
  INTO v_rider_name
  FROM public.rider_identities
  WHERE id = v_rider_identity_id;

  -- Use first name only
  v_rider_name := split_part(v_rider_name, ' ', 1);

  -- 10. Build notification body
  IF v_rating_value = 5 THEN
    v_notif_body := v_rider_name || ' rated you 5 stars and added you as a Favorite Driver.';
  ELSE
    v_notif_body := v_rider_name || ' added you as a Favorite Driver.';
  END IF;

  -- 11. Insert driver notification
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

  -- 12. Write audit event
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

  -- 13. Trigger FCM push via driver-agent Edge Function (fire-and-forget)
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

-- ============================================================
-- 2. fn_driver_favorite_summary
-- Returns: total_saved_by_riders, added_this_week, recent[]
-- Recent items: rider_first_name, added_at, rating (privacy-safe)
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_driver_favorite_summary(
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_total       integer;
  v_this_week   integer;
  v_recent      jsonb;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_driver_id');
  END IF;

  -- Total active favorites for this driver
  SELECT COUNT(*) INTO v_total
  FROM public.rider_favorite_drivers
  WHERE driver_id = p_driver_id
    AND is_active = true;

  -- Added this week
  SELECT COUNT(*) INTO v_this_week
  FROM public.rider_favorite_drivers
  WHERE driver_id = p_driver_id
    AND is_active = true
    AND created_at >= date_trunc('week', now());

  -- Recent 5 (privacy-safe: first name only, date, rating)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rider_first_name', split_part(COALESCE(ri.booking_name, split_part(ri.email, '@', 1)), ' ', 1),
    'added_at', rfd.created_at,
    'rating', rr.rider_rating_of_driver
  ) ORDER BY rfd.created_at DESC), '[]'::jsonb) INTO v_recent
  FROM public.rider_favorite_drivers rfd
  JOIN public.rider_identities ri ON ri.id = rfd.rider_identity_id
  LEFT JOIN public.ride_ratings rr ON rr.id = rfd.rating_id
  WHERE rfd.driver_id = p_driver_id
    AND rfd.is_active = true
  LIMIT 5;

  RETURN jsonb_build_object(
    'success', true,
    'total_saved_by_riders', v_total,
    'added_this_week', v_this_week,
    'recent', v_recent
  );
END;
$function$;
