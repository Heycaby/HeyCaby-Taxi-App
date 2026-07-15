-- Recheck mutable Driver eligibility inside the same locked transaction that
-- assigns an instant / Taxi Terug ride. The existing stable result contract,
-- Rider notification, competing-invite closure and audit path are preserved.
CREATE OR REPLACE FUNCTION public.fn_ensure_driver_ride_invite(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_window_seconds int := 3600;
  v_driver public.drivers%ROWTYPE;
  v_cfg jsonb;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND
     OR v_ride.status IS DISTINCT FROM 'pending'
     OR (v_ride.expires_at IS NOT NULL AND v_ride.expires_at <= now()) THEN
    RETURN false;
  END IF;

  -- Instant dispatch has an immutable server-created invite cohort.
  IF v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = p_ride_request_id
        AND i.driver_id = p_driver_id
        AND i.status = 'pending'
        AND i.expires_at > now()
    );
  END IF;

  IF v_ride.pickup_coords IS NULL THEN
    RETURN false;
  END IF;

  -- An expired invite is never usable. An open Taxi Terug browse action may
  -- renew it through the idempotent upsert below while the ride remains live.
  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = p_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN true;
  END IF;

  SELECT * INTO v_driver
  FROM public.drivers d
  WHERE d.id = p_driver_id;

  IF NOT FOUND OR v_driver.status::text IS DISTINCT FROM 'available' THEN
    RETURN false;
  END IF;

  IF COALESCE(
    (public.fn_driver_can_accept_rides(p_driver_id)->>'allowed')::boolean,
    false
  ) IS NOT TRUE THEN
    RETURN false;
  END IF;

  IF NOT public.fn_payment_compatible(p_driver_id, v_ride.payment_methods) THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_locations dl
    WHERE dl.driver_id = p_driver_id
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - interval '5 minutes'
  ) THEN
    RETURN false;
  END IF;

  v_cfg := public.fn_taxi_terug_config();
  v_window_seconds := GREATEST(
    COALESCE((v_cfg->>'invite_window_seconds')::int, 30),
    3600
  );

  INSERT INTO public.ride_request_invites (
    ride_request_id,
    driver_id,
    batch_no,
    invited_at,
    expires_at,
    status
  )
  VALUES (
    p_ride_request_id,
    p_driver_id,
    0,
    now(),
    LEAST(
      now() + make_interval(secs => v_window_seconds),
      COALESCE(v_ride.expires_at, now() + make_interval(secs => v_window_seconds))
    ),
    'pending'
  )
  ON CONFLICT (ride_request_id, driver_id) DO UPDATE
    SET status = 'pending',
        expires_at = EXCLUDED.expires_at,
        invited_at = now()
  WHERE public.ride_request_invites.status NOT IN ('accepted', 'superseded');

  RETURN EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = p_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  );
END;
$$;

COMMENT ON FUNCTION public.fn_ensure_driver_ride_invite(uuid, uuid)
IS 'Internal exact-invite guard. Instant requires a live invite; open Taxi Terug may create or renew one bounded by ride expiry.';

CREATE OR REPLACE FUNCTION public.fn_driver_accept_ride_invite(
  p_ride_request_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_billing jsonb;
  v_eligibility jsonb;
  v_ride public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_conversation_id uuid;
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
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'not_a_driver',
      'reason', 'not_a_driver',
      'message', 'Driver profile not found for this account.'
    )::json;
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
      'ok', true,
      'already_accepted', true,
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

  -- A grace period may keep an invite diagnostically visible, but it must never
  -- make the underlying ride itself acceptible after its server expiry.
  IF v_ride.expires_at IS NOT NULL AND v_ride.expires_at <= now() THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'ride_expired',
      'reason', 'ride_expired',
      'message', 'This ride is no longer available.',
      'details', jsonb_build_object('ride_expires_at', v_ride.expires_at)
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
      'message', COALESCE(
        v_billing->>'reason',
        'Outstanding platform fees exceed market limit.'
      ),
      'details', v_billing
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_rate_profiles rp
    WHERE rp.driver_id = v_driver_id
      AND rp.is_active = true
  ) THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'missing_tariff',
      'reason', 'missing_tariff',
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
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND dl.updated_at > now() - interval '5 minutes'
  ORDER BY dl.updated_at DESC
  LIMIT 1;

  IF v_gps_updated_at IS NULL THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'stale_location',
      'reason', 'gps_stale',
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
      'ok', false,
      'error', 'payment_incompatible',
      'reason', 'payment_mismatch',
      'message', 'This ride uses a payment method you do not support.',
      'details', jsonb_build_object(
        'ride_payment_methods', v_ride.payment_methods
      )
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  v_eligibility := public.fn_driver_accept_runtime_eligibility(
    v_driver_id,
    v_ride
  );
  IF COALESCE((v_eligibility->>'eligible')::boolean, false) IS NOT TRUE THEN
    v_reject := jsonb_build_object(
      'ok', false,
      'error', 'driver_not_eligible',
      'reason', COALESCE(v_eligibility->>'reason', 'driver_not_eligible'),
      'message', COALESCE(
        v_eligibility->>'message',
        'You are no longer eligible for this ride.'
      ),
      'details', v_eligibility - 'message'
    );
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'dispatch.accept_rejected', v_driver_id,
      v_reject, 'driver', 'rpc', p_ride_request_id
    );
    RETURN v_reject::json;
  END IF;

  -- Taxi Terug browse acceptance may create the exact invite here. Normal
  -- dispatch must already have created it. Both paths are validated below.
  PERFORM public.fn_ensure_driver_ride_invite(
    p_ride_request_id,
    v_driver_id
  );
  v_invite_diag := public.fn_accept_invite_diagnostic(
    p_ride_request_id,
    v_driver_id,
    v_accept_grace
  );

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = v_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
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
      'ok', false,
      'error', 'race_lost',
      'reason', 'database_conflict',
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
    AND i.status = 'pending'
    AND i.expires_at > now();

  INSERT INTO public.conversations (
    ride_request_id,
    driver_id,
    rider_identity_id
  )
  VALUES (
    p_ride_request_id,
    v_driver_id,
    v_ride.rider_identity_id
  )
  ON CONFLICT (ride_request_id) DO UPDATE
  SET driver_id = EXCLUDED.driver_id
  RETURNING id INTO v_conversation_id;

  SELECT * INTO v_driver
  FROM public.drivers d
  WHERE d.id = v_driver_id;

  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'driver_found',
    'Driver found',
    COALESCE(v_driver.full_name, 'Your driver') || ' accepted your ride',
    jsonb_build_object(
      'type', 'driver_found',
      'driver_name', v_driver.full_name,
      'conversation_id', v_conversation_id
    ),
    'critical'
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'ride.accepted',
    v_driver_id,
    jsonb_build_object('conversation_id', v_conversation_id),
    'driver',
    'rpc',
    p_ride_request_id
  );

  PERFORM public.fn_taxi_terug_queue_accepted_invite(
    p_ride_request_id,
    v_driver_id
  );

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'conversation_id', v_conversation_id
  );
END;
$$;

COMMENT ON FUNCTION public.fn_driver_accept_ride_invite(uuid)
IS 'Atomic exact-invite acceptance with locked ride, server expiry, runtime eligibility, stable errors, competing-invite closure, Rider notify and audit.';

REVOKE ALL ON FUNCTION public.fn_driver_accept_ride_invite(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_ride_invite(uuid)
TO authenticated;
