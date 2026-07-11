-- Lifecycle RPCs: centralized rider notify helper for accept/start/complete.
CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_d public.drivers%ROWTYPE;
  v_conversation_id uuid;
  v_rider_target text;
  v_accept_grace int := 30;
  v_invite_diag jsonb;
  v_gps_updated_at timestamptz;
  v_reject jsonb;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'not_a_driver',
      'reason', 'not_a_driver',
      'message', 'Driver profile not found for this account.'
    );
    RETURN v_reject::json;
  END IF;

  IF to_regprocedure('public.fn_dispatch_config()') IS NOT NULL THEN
    v_accept_grace := COALESCE(
      (public.fn_dispatch_config()->>'min_driver_accept_window_seconds')::int,
      30
    );
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'ride_not_found',
      'reason', 'ride_not_found',
      'message', 'This ride no longer exists.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.status = 'cancelled' THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'rider_cancelled',
      'reason', 'rider_cancelled',
      'message', 'The rider cancelled this trip.',
      'details', jsonb_build_object(
        'cancelled_by', v_ride.cancelled_by,
        'cancellation_reason', v_ride.cancellation_reason
      )
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF v_ride.status = 'accepted' AND v_ride.driver_id = v_driver_id THEN
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    WHERE c.ride_request_id = p_ride_request_id;
    RETURN json_build_object(
      'ok', true, 'already_accepted', true,
      'ride_id', p_ride_request_id,
      'conversation_id', v_conversation_id
    );
  END IF;

  IF v_ride.status <> 'pending' THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'race_lost',
      'reason', 'ride_not_pending',
      'message', 'Another driver already accepted this ride.',
      'details', jsonb_build_object(
        'ride_status', v_ride.status,
        'ride_driver_id', v_ride.driver_id
      )
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  IF COALESCE((v_billing->>'allowed')::boolean, false) = false THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'billing_locked',
      'reason', 'billing_locked',
      'message', COALESCE(v_billing->>'reason', 'Outstanding platform fees exceed market limit.'),
      'details', v_billing
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  PERFORM public.fn_ensure_driver_ride_invite(p_ride_request_id, v_driver_id);
  v_invite_diag := public.fn_accept_invite_diagnostic(
    p_ride_request_id, v_driver_id, v_accept_grace
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status IN ('pending', 'wave_expired', 'expired')
      AND i.expires_at > now() - make_interval(secs => v_accept_grace)
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'no_valid_invite',
      'reason', CASE
        WHEN COALESCE((v_invite_diag->>'invite_exists')::boolean, false) = false
          THEN 'invite_missing'
        WHEN COALESCE((v_invite_diag->>'invite_expired')::boolean, false) = true
          THEN 'invite_expired'
        ELSE 'invite_not_pending'
      END,
      'message', CASE
        WHEN COALESCE((v_invite_diag->>'invite_exists')::boolean, false) = false
          THEN 'No invite found for this driver on this ride.'
        WHEN COALESCE((v_invite_diag->>'invite_expired')::boolean, false) = true
          THEN 'Your invite window has passed.'
        ELSE 'Invite is not in a valid state for accept.'
      END,
      'details', v_invite_diag || jsonb_build_object(
        'accept_grace_seconds', v_accept_grace,
        'ride_status', v_ride.status,
        'ride_expires_at', v_ride.expires_at
      )
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id AND rp.is_active = true
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'missing_tariff', 'reason', 'missing_tariff',
      'message', 'Set your tariff before accepting rides.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  SELECT dl.updated_at INTO v_gps_updated_at
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
    AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
    AND dl.updated_at > now() - interval '5 minutes'
  LIMIT 1;

  IF v_gps_updated_at IS NULL THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'stale_location', 'reason', 'gps_stale',
      'message', 'Your GPS location is stale. Enable location and try again.',
      'details', jsonb_build_object('gps_freshness_minutes', 5)
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT public.fn_payment_compatible(v_driver_id, v_ride.payment_methods) THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'payment_incompatible', 'reason', 'payment_mismatch',
      'message', 'This ride uses a payment method you do not support.',
      'details', jsonb_build_object('ride_payment_methods', v_ride.payment_methods)
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'accepted',
      driver_id = v_driver_id,
      accepted_at = timezone('utc', now()),
      updated_at = now()
  WHERE rr.id = p_ride_request_id
    AND rr.status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    v_reject := jsonb_build_object(
      'ok', false, 'error', 'race_lost', 'reason', 'database_conflict',
      'message', 'Another driver accepted this ride first.'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'superseded'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id <> v_driver_id
    AND i.status IN ('pending', 'wave_expired', 'expired');

  UPDATE public.ride_request_invites i
  SET status = 'accepted'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.driver_id = v_driver_id
    AND i.status IN ('pending', 'wave_expired', 'expired');

  INSERT INTO public.conversations (ride_request_id, driver_id, rider_identity_id)
  VALUES (p_ride_request_id, v_driver_id, v_ride.rider_identity_id)
  ON CONFLICT (ride_request_id) DO UPDATE
  SET driver_id = EXCLUDED.driver_id
  RETURNING id INTO v_conversation_id;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'driver_found',
    'Driver found',
    COALESCE(v_d.full_name, 'Your driver') || ' accepted your ride',
    jsonb_build_object(
      'type', 'driver_found',
      'driver_name', v_d.full_name,
      'conversation_id', v_conversation_id
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'ride.accepted', v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver', 'rpc', p_ride_request_id
  );

  PERFORM public.fn_taxi_terug_queue_accepted_invite(p_ride_request_id, v_driver_id);

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_accept_ride_invite(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_ride_invite(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_driver_ride_start(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_max_m numeric;
  v_dist_m numeric;
  v_wait_secs int;
  v_fee_cents int;
  v_rider_target text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status <> 'driver_arrived' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  -- Proximity guard (default 200 m), enforced when verifiable.
  v_max_m := COALESCE(NULLIF(public.fn_app_config_text('start_max_distance_m'), '')::numeric, 200);
  SELECT ST_Distance(
           ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
           v_ride.pickup_coords
         )
  INTO v_dist_m
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
    AND dl.updated_at > now() - interval '3 minutes'
    AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
    AND v_ride.pickup_coords IS NOT NULL
  LIMIT 1;

  IF v_dist_m IS NOT NULL AND v_dist_m > v_max_m THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'trip.start_blocked_distance', v_driver_id,
      jsonb_build_object('distance_m', round(v_dist_m), 'max_m', v_max_m),
      'driver', 'rpc', p_ride_request_id
    );
    RETURN json_build_object(
      'ok', false, 'error', 'too_far_from_pickup',
      'distance_m', round(v_dist_m), 'max_m', v_max_m
    );
  END IF;

  -- Freeze waiting values at boarding.
  v_wait_secs := GREATEST(
    0,
    COALESCE(
      EXTRACT(EPOCH FROM (timezone('utc', now()) - v_ride.driver_arrived_at))::int, 0
    ) - COALESCE(v_ride.waiting_grace_seconds, 120)
  );
  IF COALESCE(v_ride.waiting_fee_waived, false) THEN
    v_fee_cents := 0;
  ELSE
    v_fee_cents := round(
      (v_wait_secs / 60.0) * COALESCE(v_ride.waiting_rate_per_minute, 0) * 100
    )::int;
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'in_progress',
      started_at = timezone('utc', now()),
      chargeable_wait_seconds = v_wait_secs,
      waiting_fee_cents = v_fee_cents,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.started', v_driver_id,
    jsonb_build_object(
      'status', 'in_progress',
      'chargeable_wait_seconds', v_wait_secs,
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'ride_started',
    'Your trip has started',
    'Enjoy your ride.',
    jsonb_build_object('type', 'ride_started'),
    'high'
  );

  RETURN json_build_object(
    'ok', true, 'status', 'in_progress', 'ride_id', p_ride_request_id,
    'chargeable_wait_seconds', v_wait_secs,
    'waiting_fee_cents', v_fee_cents
  );
END;
$$;

-- 5) Complete ride: waiting transparency in audit + rider completion notification

CREATE OR REPLACE FUNCTION public.fn_driver_ride_complete(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
  v_fee_cents int;
  v_queued jsonb;
  v_terug_stats jsonb;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status <> 'in_progress' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  v_fee_cents := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)
  END;

  UPDATE public.ride_requests rr
  SET status = 'completed',
      completed_at = timezone('utc', now()),
      waiting_fee_cents = v_fee_cents,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  IF v_ride.booking_mode::text = 'terug' THEN
    v_terug_stats := public.fn_taxi_terug_record_completion(p_ride_request_id, v_driver_id);
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);
  v_queued := public.fn_taxi_terug_activate_queued_ride(v_driver_id, p_ride_request_id);
  PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_request_id, v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.completed', v_driver_id,
    jsonb_build_object(
      'status', 'completed',
      'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false),
      'queued_taxi_terug_activated', COALESCE((v_queued->>'ok')::boolean, false),
      'taxi_terug_stats', v_terug_stats
    )
  );

  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'ride_completed',
    'Trip completed',
    'Thanks for riding with HeyCaby. Rate your driver.',
    jsonb_build_object(
      'type', 'ride_completed',
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    ),
    'high'
  );

  RETURN json_build_object(
    'ok', true, 'status', 'completed', 'ride_id', p_ride_request_id,
    'waiting_fee_cents', v_fee_cents,
    'queued_taxi_terug_activated', COALESCE((v_queued->>'ok')::boolean, false),
    'taxi_terug_empty_km_saved', v_terug_stats->>'empty_km_saved',
    'taxi_terug_earnings_euros', v_terug_stats->>'earnings_euros'
  );
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

REVOKE ALL ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_rate_driver(uuid, smallint, text, text) TO anon, authenticated;