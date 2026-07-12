-- One authoritative, idempotent cancellation transition for every
-- non-terminal, non-scheduled rider journey.
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
  v_reason text := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_driver record;
  v_notified_user_ids uuid[] := '{}';
  v_notification_failures integer := 0;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride FROM public.ride_requests
  WHERE id = p_ride_request_id FOR UPDATE;
  IF NOT FOUND THEN RETURN json_build_object('ok', false, 'error', 'ride_not_found'); END IF;
  IF v_ride.status = 'cancelled' THEN
    RETURN json_build_object('ok', true, 'status', 'cancelled',
      'ride_id', p_ride_request_id, 'already_cancelled', true);
  END IF;
  IF v_ride.status IN ('completed', 'expired') THEN
    RETURN json_build_object('ok', false, 'error', 'terminal_ride', 'status', v_ride.status);
  END IF;

  IF v_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
  END IF;
  IF NOT v_auth_ok AND NULLIF(btrim(COALESCE(p_rider_token, '')), '') IS NOT NULL
     AND v_ride.rider_token = btrim(p_rider_token) THEN v_auth_ok := true; END IF;
  IF NOT v_auth_ok AND auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.rider_sessions rs
    WHERE rs.user_id = auth.uid() AND rs.session_token = v_ride.rider_token
  ) THEN v_auth_ok := true; END IF;
  IF NOT v_auth_ok THEN RETURN json_build_object('ok', false, 'error', 'not_authorized'); END IF;

  IF COALESCE(v_ride.is_scheduled, false)
     OR v_ride.scheduled_pickup_at IS NOT NULL
     OR v_ride.booking_mode::text = 'scheduled' THEN
    RETURN json_build_object('ok', false, 'error', 'scheduled_ride_separate_flow');
  END IF;

  UPDATE public.ride_requests SET
    status = 'cancelled', cancelled_at = timezone('utc', now()),
    cancelled_by = 'rider', cancellation_reason = v_reason,
    expires_at = COALESCE(expires_at, timezone('utc', now())),
    updated_at = timezone('utc', now())
  WHERE id = p_ride_request_id;

  UPDATE public.ride_request_invites SET status = 'superseded'
  WHERE ride_request_id = p_ride_request_id
    AND status IN ('pending', 'wave_expired', 'expired');

  FOR v_driver IN
    SELECT DISTINCT d.user_id
    FROM public.drivers d
    WHERE d.user_id IS NOT NULL AND (
      d.id = v_ride.driver_id OR d.id IN (
        SELECT i.driver_id FROM public.ride_request_invites i
        WHERE i.ride_request_id = p_ride_request_id
      )
    )
  LOOP
    IF v_driver.user_id = ANY(v_notified_user_ids) THEN CONTINUE; END IF;
    v_notified_user_ids := array_append(v_notified_user_ids, v_driver.user_id);
    BEGIN
      PERFORM public.fn_ride_event_notify(
        'driver', v_driver.user_id::text, 'ride_phase',
        'Rider cancelled', 'This trip was cancelled by the rider.',
        jsonb_build_object(
          'type', 'rider_cancelled', 'ride_request_id', p_ride_request_id,
          'cancelled_by', 'rider', 'status', 'cancelled', 'screen', 'home'
        ), 'critical'
      );
    EXCEPTION WHEN OTHERS THEN
      v_notification_failures := v_notification_failures + 1;
    END;
  END LOOP;

  BEGIN
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'ride.cancelled', auth.uid(),
      jsonb_build_object(
        'actor', 'rider', 'reason', v_reason,
        'previous_status', v_ride.status,
        'notification_failures', v_notification_failures
      ), 'rider', 'rpc', p_ride_request_id
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN json_build_object(
    'ok', true, 'status', 'cancelled', 'ride_id', p_ride_request_id,
    'previous_status', v_ride.status,
    'notified_driver_count', cardinality(v_notified_user_ids),
    'notification_failures', v_notification_failures
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text) TO authenticated, anon;

COMMENT ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text) IS
'Authoritative idempotent cancellation for all non-terminal instant rides; revokes invites and notifies assigned/invited driver auth identities.';
