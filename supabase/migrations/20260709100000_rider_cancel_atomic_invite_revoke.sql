-- Atomic rider cancel during matching: cancel ride, revoke pending invites,
-- and notify every invited driver so ringing stops immediately.

CREATE OR REPLACE FUNCTION public.fn_rider_cancel_open_ride(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL,
  p_reason text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_auth_ok boolean := false;
  v_driver_id uuid;
  v_reason text := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_revoked record;
  v_notified uuid[] := '{}';
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status = 'cancelled' THEN
    RETURN json_build_object(
      'ok', true,
      'status', 'cancelled',
      'ride_id', p_ride_request_id,
      'already_cancelled', true
    );
  END IF;

  IF v_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id
        AND ri.user_id = auth.uid()
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
    RETURN json_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  IF v_ride.status NOT IN ('pending', 'bidding', 'no_driver') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'cancelled',
      cancelled_at = timezone('utc', now()),
      cancelled_by = 'rider',
      cancellation_reason = v_reason,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  FOR v_revoked IN
    UPDATE public.ride_request_invites i
    SET status = 'superseded'
    WHERE i.ride_request_id = p_ride_request_id
      AND i.status IN ('pending', 'wave_expired')
    RETURNING i.driver_id
  LOOP
    v_driver_id := v_revoked.driver_id;
    IF v_driver_id IS NULL OR v_driver_id = ANY(v_notified) THEN
      CONTINUE;
    END IF;
    v_notified := array_append(v_notified, v_driver_id);
    PERFORM public.fn_ride_event_notify(
      'driver',
      v_driver_id::text,
      'ride_phase',
      'Rider cancelled',
      'This trip was cancelled by the rider.',
      jsonb_build_object(
        'type', 'rider_cancelled',
        'ride_request_id', p_ride_request_id,
        'cancelled_by', 'rider',
        'screen', 'home'
      ),
      'critical'
    );
  END LOOP;

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'ride.cancelled',
    NULL,
    jsonb_build_object(
      'actor', 'rider',
      'reason', v_reason,
      'previous_status', v_ride.status
    ),
    'rider',
    'rpc',
    p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'status', 'cancelled',
    'ride_id', p_ride_request_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text) TO authenticated, anon;

COMMENT ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text) IS
  'Rider cancels a matching ride atomically: revokes pending invites and notifies invited drivers.';
