-- Cancellation is authoritative. Notification/audit delivery may report a
-- failure, but can never roll the ride row back to an active state.

CREATE OR REPLACE FUNCTION public.fn_ride_event_notify(
  p_user_type text,
  p_user_id text,
  p_category text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_priority text DEFAULT 'high'
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_agent text;
BEGIN
  IF p_user_id IS NULL OR btrim(p_user_id) = '' THEN RETURN NULL; END IF;
  v_agent := CASE lower(btrim(COALESCE(p_user_type, '')))
    WHEN 'driver' THEN 'driver_agent'
    WHEN 'rider' THEN 'rider_agent'
    ELSE 'cs_agent'
  END;
  INSERT INTO public.notifications (
    user_type, user_id, agent, category, title, body, data, priority, channel
  ) VALUES (
    p_user_type, p_user_id, v_agent, p_category, p_title, p_body,
    COALESCE(p_data, '{}'::jsonb), COALESCE(p_priority, 'high'), 'both'
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_ride_event_notify(
  text, text, text, text, text, jsonb, text
) FROM PUBLIC, anon, authenticated;

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
  v_revoked record;
  v_notified uuid[] := '{}';
  v_notification_failures integer := 0;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;
  IF v_ride.status = 'cancelled' THEN
    RETURN json_build_object('ok', true, 'status', 'cancelled',
      'ride_id', p_ride_request_id, 'already_cancelled', true);
  END IF;

  IF v_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
  END IF;
  IF NOT v_auth_ok AND NULLIF(btrim(COALESCE(p_rider_token, '')), '') IS NOT NULL
     AND v_ride.rider_token = btrim(p_rider_token) THEN
    v_auth_ok := true;
  END IF;
  IF NOT v_auth_ok AND auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.rider_sessions rs
    WHERE rs.user_id = auth.uid() AND rs.session_token = v_ride.rider_token
  ) THEN v_auth_ok := true; END IF;
  IF NOT v_auth_ok THEN
    RETURN json_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  IF COALESCE(v_ride.is_scheduled, false)
     OR v_ride.scheduled_pickup_at IS NOT NULL
     OR v_ride.booking_mode::text = 'scheduled' THEN
    RETURN json_build_object('ok', false, 'error', 'scheduled_ride_separate_flow');
  END IF;
  IF v_ride.status NOT IN ('pending', 'bidding', 'no_driver') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition',
      'status', v_ride.status);
  END IF;

  UPDATE public.ride_requests SET
    status = 'cancelled', cancelled_at = timezone('utc', now()),
    cancelled_by = 'rider', cancellation_reason = v_reason,
    expires_at = COALESCE(expires_at, timezone('utc', now())),
    updated_at = timezone('utc', now())
  WHERE id = p_ride_request_id;

  FOR v_revoked IN
    UPDATE public.ride_request_invites SET status = 'superseded'
    WHERE ride_request_id = p_ride_request_id
      AND status IN ('pending', 'wave_expired', 'expired')
    RETURNING driver_id
  LOOP
    IF v_revoked.driver_id IS NULL OR v_revoked.driver_id = ANY(v_notified) THEN
      CONTINUE;
    END IF;
    v_notified := array_append(v_notified, v_revoked.driver_id);
    BEGIN
      PERFORM public.fn_ride_event_notify(
        'driver', v_revoked.driver_id::text, 'ride_phase',
        'Rider cancelled', 'This trip was cancelled by the rider.',
        jsonb_build_object('type', 'rider_cancelled',
          'ride_request_id', p_ride_request_id, 'cancelled_by', 'rider',
          'screen', 'home'), 'critical'
      );
    EXCEPTION WHEN OTHERS THEN
      v_notification_failures := v_notification_failures + 1;
    END;
  END LOOP;

  BEGIN
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'ride.cancelled', NULL,
      jsonb_build_object('actor', 'rider', 'reason', v_reason,
        'previous_status', v_ride.status,
        'notification_failures', v_notification_failures),
      'rider', 'rpc', p_ride_request_id
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN json_build_object('ok', true, 'status', 'cancelled',
    'ride_id', p_ride_request_id,
    'revoked_driver_count', cardinality(v_notified),
    'notification_failures', v_notification_failures);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_cancel_open_ride(uuid, text, text)
  TO authenticated, anon;

-- One backend clock for instant search: ten minutes from creation. Scheduled
-- rides are deliberately excluded and keep their own lifecycle.
CREATE OR REPLACE FUNCTION public.fn_expire_ride_requests()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  WITH expired AS (
    UPDATE public.ride_requests rr SET
      status = 'expired',
      expires_at = COALESCE(rr.expires_at, rr.created_at + interval '10 minutes'),
      updated_at = timezone('utc', now())
    WHERE rr.status IN ('pending', 'bidding', 'no_driver')
      AND COALESCE(rr.is_scheduled, false) = false
      AND rr.scheduled_pickup_at IS NULL
      AND rr.booking_mode::text <> 'scheduled'
      AND COALESCE(rr.expires_at, rr.created_at + interval '10 minutes') <= now()
    RETURNING rr.id
  )
  UPDATE public.ride_request_invites i SET status = 'expired'
  WHERE i.status IN ('pending', 'wave_expired')
    AND i.ride_request_id IN (SELECT id FROM expired);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_expire_ride_requests()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_expire_ride_requests() TO service_role;

-- Clean up legacy instant searches that survived because expires_at was null.
SELECT public.fn_expire_ride_requests();
