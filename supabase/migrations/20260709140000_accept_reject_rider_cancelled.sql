-- Reject accept on rider-cancelled rides; harden cancel auth via session bind.

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
  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'driver_found',
    'Driver found',
    COALESCE(v_d.full_name, 'Your driver') || ' is on the way',
    jsonb_build_object(
      'type', 'driver_found',
      'ride_request_id', p_ride_request_id,
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
