-- Phase F: operational hardening for Secure Shift Handover.
-- Aligns the platform flow with a 2-minute handover, denial cooldowns,
-- per-plate request limits, and queued transfer while an active ride is in progress.

DROP FUNCTION IF EXISTS public.fn_driver_shift_handover_grace_seconds();

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_grace_seconds(
  p_ownership_type text DEFAULT 'shared_fleet'
)
RETURNS int
LANGUAGE sql
IMMUTABLE
AS $$ SELECT 120; $$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_check_rate_limit(
  p_requester_id uuid,
  p_vehicle_id uuid,
  p_plate_norm text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_last_denied timestamptz;
  v_deny_count int;
  v_plate_hour_count int;
BEGIN
  SELECT count(*) INTO v_plate_hour_count
  FROM public.shift_handover_requests shr
  WHERE (shr.vehicle_id = p_vehicle_id OR shr.plate_normalized = p_plate_norm)
    AND shr.requested_at > timezone('utc', now()) - interval '1 hour'
    AND shr.status <> 'cancelled';

  IF v_plate_hour_count >= 3 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'handover_plate_rate_limited',
      'message', 'Er zijn te veel dienstwissel-aanvragen voor deze taxi. Probeer het over een uur opnieuw of neem contact op met ondersteuning.',
      'retry_after', timezone('utc', now()) + interval '1 hour'
    );
  END IF;

  SELECT count(*) INTO v_deny_count
  FROM public.shift_handover_requests shr
  WHERE shr.requesting_driver_id = p_requester_id
    AND (shr.vehicle_id = p_vehicle_id OR shr.plate_normalized = p_plate_norm)
    AND shr.status = 'denied'
    AND shr.resolved_at > timezone('utc', now()) - interval '24 hours';

  IF v_deny_count >= 2 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'handover_blocked',
      'message', 'Te veel geweigerde pogingen voor deze taxi. Probeer het over 24 uur opnieuw of neem contact op met ondersteuning.',
      'retry_after', timezone('utc', now()) + interval '24 hours'
    );
  END IF;

  SELECT shr.resolved_at INTO v_last_denied
  FROM public.shift_handover_requests shr
  WHERE shr.requesting_driver_id = p_requester_id
    AND (shr.vehicle_id = p_vehicle_id OR shr.plate_normalized = p_plate_norm)
    AND shr.status = 'denied'
  ORDER BY shr.resolved_at DESC
  LIMIT 1;

  IF v_last_denied IS NOT NULL
     AND v_last_denied > timezone('utc', now()) - interval '30 minutes' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'handover_cooldown',
      'message', 'De vorige aanvraag is geweigerd. Probeer het over 30 minuten opnieuw.',
      'retry_after', v_last_denied + interval '30 minutes'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_request(
  p_vehicle_plate text,
  p_vehicle_plate_entered text DEFAULT NULL,
  p_rdw_snapshot jsonb DEFAULT '{}'::jsonb,
  p_vehicle_verification_status text DEFAULT 'rdw_verified_taxi',
  p_step_up_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_id uuid;
  v_requester_driver public.drivers%ROWTYPE;
  v_plate_norm text;
  v_plate_display text;
  v_vehicle public.taxi_vehicles%ROWTYPE;
  v_current_driver_id uuid;
  v_current_user uuid;
  v_grace int;
  v_req_id uuid;
  v_expires timestamptz;
  v_requester_snapshot jsonb;
  v_requester_name text;
  v_notify_body text;
  v_rate jsonb;
  v_allow jsonb;
  v_has_active_ride boolean;
  v_step_up_method text;
BEGIN
  SELECT d.* INTO v_requester_driver
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  v_requester_id := v_requester_driver.id;

  IF v_requester_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  IF p_step_up_id IS NULL
     OR NOT public.fn_driver_shift_handover_consume_step_up(p_step_up_id, v_requester_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'step_up_required',
      'message', 'Bevestig je identiteit voordat je een Secure Shift Handover aanvraagt.'
    );
  END IF;

  IF NOT (
    COALESCE(v_requester_driver.veriff_status, '') IN ('approved', 'verified')
    OR COALESCE(v_requester_driver.rijbewijs_verified, false)
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'handover_not_eligible',
      'message', 'Rond je verificatie af voordat je een dienstwissel kunt aanvragen.'
    );
  END IF;

  v_plate_norm := upper(regexp_replace(trim(p_vehicle_plate), '[\s\-]', '', 'g'));
  v_plate_display := COALESCE(NULLIF(trim(p_vehicle_plate_entered), ''), v_plate_norm);
  IF length(v_plate_norm) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_plate');
  END IF;

  SELECT tv.* INTO v_vehicle
  FROM public.taxi_vehicles tv
  WHERE tv.plate_normalized = v_plate_norm
  LIMIT 1;

  IF v_vehicle.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'vehicle_not_registered', 'direct_claim', true);
  END IF;

  v_rate := public.fn_driver_shift_handover_check_rate_limit(
    v_requester_id,
    v_vehicle.id,
    v_plate_norm
  );
  IF COALESCE((v_rate->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_rate;
  END IF;

  v_allow := public.fn_driver_shift_handover_check_allowlist(
    v_requester_id,
    v_vehicle.id,
    v_vehicle.ownership_type
  );
  IF COALESCE((v_allow->>'ok')::boolean, false) IS NOT TRUE THEN
    PERFORM public.fn_driver_shift_handover_log_security(
      'shift_handover_allowlist_blocked',
      v_plate_norm,
      jsonb_build_object('vehicle_id', v_vehicle.id, 'requesting_driver_id', v_requester_id)
    );
    RETURN v_allow;
  END IF;

  IF v_vehicle.ownership_type = 'private'
     AND v_vehicle.owner_driver_id IS NOT NULL
     AND v_vehicle.owner_driver_id <> v_requester_id THEN
    PERFORM public.fn_driver_shift_handover_log_security(
      'shift_handover_private_blocked',
      v_plate_norm,
      jsonb_build_object('vehicle_id', v_vehicle.id, 'owner_driver_id', v_vehicle.owner_driver_id)
    );
    PERFORM public.fn_driver_shift_handover_notify_private_owner_attempt(
      v_vehicle.id,
      v_requester_id,
      v_plate_display
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'private_taxi_owner_only',
      'message', 'Deze taxi is privé geregistreerd en kan niet door andere chauffeurs worden geactiveerd.'
    );
  END IF;

  v_grace := public.fn_driver_shift_handover_grace_seconds(v_vehicle.ownership_type);

  SELECT tvs.driver_id INTO v_current_driver_id
  FROM public.taxi_vehicle_sessions tvs
  WHERE tvs.vehicle_id = v_vehicle.id
    AND tvs.is_active = true
    AND tvs.ended_at IS NULL
    AND tvs.driver_id <> v_requester_id
  LIMIT 1;

  IF v_current_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_active_session', 'direct_claim', true);
  END IF;

  v_has_active_ride := public.fn_driver_has_active_ride(v_current_driver_id);

  v_requester_snapshot := COALESCE(
    public.fn_driver_shift_handover_requester_snapshot(v_requester_id),
    '{}'::jsonb
  );
  v_requester_name := COALESCE(v_requester_snapshot->>'requester_name', 'Een chauffeur');

  UPDATE public.shift_handover_requests
  SET status = 'cancelled',
      resolved_at = timezone('utc', now()),
      resolution_reason = 'superseded'
  WHERE requesting_driver_id = v_requester_id
    AND vehicle_id = v_vehicle.id
    AND status = 'pending';

  v_expires := CASE
    WHEN v_has_active_ride THEN timezone('utc', now()) + interval '24 hours'
    ELSE timezone('utc', now()) + make_interval(secs => v_grace)
  END;

  SELECT su.method INTO v_step_up_method
  FROM public.shift_handover_step_ups su
  WHERE su.id = p_step_up_id
  LIMIT 1;

  INSERT INTO public.shift_handover_requests (
    vehicle_id,
    requesting_driver_id,
    current_driver_id,
    plate_normalized,
    plate_display,
    rdw_snapshot,
    vehicle_verification_status,
    expires_at,
    metadata
  )
  VALUES (
    v_vehicle.id,
    v_requester_id,
    v_current_driver_id,
    v_plate_norm,
    v_plate_display,
    COALESCE(p_rdw_snapshot, '{}'::jsonb),
    COALESCE(NULLIF(trim(p_vehicle_verification_status), ''), 'rdw_verified_taxi'),
    v_expires,
    jsonb_build_object(
      'ownership_type', v_vehicle.ownership_type,
      'step_up_id', p_step_up_id,
      'step_up_method', v_step_up_method,
      'active_ride_queued', v_has_active_ride,
      'queued_reason', CASE WHEN v_has_active_ride THEN 'current_driver_active_ride' ELSE NULL END
    )
  )
  RETURNING id INTO v_req_id;

  SELECT d.user_id INTO v_current_user
  FROM public.drivers d
  WHERE d.id = v_current_driver_id;

  IF v_has_active_ride THEN
    v_notify_body := format(
      '%s wil Taxi %s na je huidige rit overnemen. De dienstwissel staat klaar zodra de rit is afgerond.',
      v_requester_name,
      v_plate_display
    );

    PERFORM public.fn_driver_shift_handover_notify(
      v_current_user,
      'Dienstwissel na huidige rit',
      v_notify_body,
      'shift_handover_queued',
      jsonb_build_object(
        'request_id', v_req_id,
        'vehicle_id', v_vehicle.id,
        'plate', v_plate_norm,
        'plate_display', v_plate_display,
        'queued_active_ride', true,
        'ownership_type', v_vehicle.ownership_type
      ) || v_requester_snapshot
    );
  ELSE
    v_notify_body := format(
      '%s wil Taxi %s besturen. Reageer binnen 2 minuten. Geen actie? Je dienst eindigt automatisch.',
      v_requester_name,
      v_plate_display
    );

    PERFORM public.fn_driver_shift_handover_notify(
      v_current_user,
      'Secure Shift Handover',
      v_notify_body,
      'shift_handover',
      jsonb_build_object(
        'request_id', v_req_id,
        'vehicle_id', v_vehicle.id,
        'plate', v_plate_norm,
        'plate_display', v_plate_display,
        'expires_at', v_expires,
        'grace_seconds', v_grace,
        'ownership_type', v_vehicle.ownership_type
      ) || v_requester_snapshot
    );
  END IF;

  PERFORM public.fn_driver_shift_handover_queue_email(
    v_current_driver_id,
    CASE WHEN v_has_active_ride THEN 'shift_handover_queued' ELSE 'shift_handover_request' END,
    'shift_handover_email_' || v_req_id::text,
    jsonb_build_object(
      'request_id', v_req_id,
      'plate', v_plate_display,
      'requester_name', v_requester_name,
      'expires_at', v_expires,
      'queued_active_ride', v_has_active_ride
    )
  );

  PERFORM public.fn_driver_shift_handover_log_security(
    CASE WHEN v_has_active_ride THEN 'shift_handover_queued_active_ride' ELSE 'shift_handover_requested' END,
    v_plate_norm,
    jsonb_build_object(
      'request_id', v_req_id,
      'requesting_driver_id', v_requester_id,
      'current_driver_id', v_current_driver_id,
      'ownership_type', v_vehicle.ownership_type,
      'active_ride_queued', v_has_active_ride
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'request_id', v_req_id,
    'status', 'pending',
    'expires_at', v_expires,
    'grace_seconds', v_grace,
    'queued_active_ride', v_has_active_ride
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_poll(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.shift_handover_requests%ROWTYPE;
  v_requester_id uuid;
  v_queued_active_ride boolean;
BEGIN
  SELECT d.id INTO v_requester_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  SELECT * INTO v_req
  FROM public.shift_handover_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF v_req.requesting_driver_id <> v_requester_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  v_queued_active_ride := COALESCE((v_req.metadata->>'active_ride_queued')::boolean, false);

  IF v_req.status = 'pending' AND v_queued_active_ride THEN
    IF public.fn_driver_has_active_ride(v_req.current_driver_id) THEN
      RETURN jsonb_build_object(
        'ok', true,
        'status', 'pending',
        'request_id', v_req.id,
        'expires_at', v_req.expires_at,
        'queued_active_ride', true,
        'message', 'Je aanvraag staat klaar. De taxi wordt automatisch overgedragen zodra de huidige rit klaar is.',
        'plate', v_req.plate_normalized,
        'vehicle_id', v_req.vehicle_id
      );
    END IF;

    RETURN public.fn_driver_shift_handover_finalize(
      p_request_id,
      'ride_finished_handover',
      'timed_out'
    );
  END IF;

  IF v_req.status = 'pending' AND timezone('utc', now()) >= v_req.expires_at THEN
    IF public.fn_driver_has_active_ride(v_req.current_driver_id) THEN
      UPDATE public.shift_handover_requests
      SET metadata = metadata || jsonb_build_object(
            'active_ride_queued', true,
            'queued_reason', 'active_ride_at_timeout',
            'queued_at', timezone('utc', now())
          ),
          expires_at = timezone('utc', now()) + interval '24 hours'
      WHERE id = p_request_id;

      RETURN jsonb_build_object(
        'ok', true,
        'status', 'pending',
        'request_id', p_request_id,
        'queued_active_ride', true,
        'message', 'Je aanvraag staat klaar. De taxi wordt automatisch overgedragen zodra de huidige rit klaar is.',
        'plate', v_req.plate_normalized,
        'vehicle_id', v_req.vehicle_id
      );
    END IF;

    RETURN public.fn_driver_shift_handover_finalize(p_request_id, 'timeout_handover', 'timed_out');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', v_req.status,
    'request_id', v_req.id,
    'expires_at', v_req.expires_at,
    'resolved_at', v_req.resolved_at,
    'resolution_reason', v_req.resolution_reason,
    'queued_active_ride', v_queued_active_ride,
    'plate', v_req.plate_normalized,
    'vehicle_id', v_req.vehicle_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_finalize_queued_for_driver(
  p_driver_id uuid
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req record;
  v_count int := 0;
BEGIN
  IF p_driver_id IS NULL OR public.fn_driver_has_active_ride(p_driver_id) THEN
    RETURN 0;
  END IF;

  FOR v_req IN
    SELECT shr.id
    FROM public.shift_handover_requests shr
    WHERE shr.current_driver_id = p_driver_id
      AND shr.status = 'pending'
      AND COALESCE((shr.metadata->>'active_ride_queued')::boolean, false)
    ORDER BY shr.requested_at ASC
    LIMIT 1
  LOOP
    PERFORM public.fn_driver_shift_handover_finalize(
      v_req.id,
      'ride_finished_handover',
      'timed_out'
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_shift_handover_ride_finished()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.driver_id IS NOT NULL
     AND NEW.status IN ('completed', 'closed', 'cancelled')
     AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.fn_driver_shift_handover_finalize_queued_for_driver(NEW.driver_id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shift_handover_ride_finished ON public.ride_requests;
CREATE TRIGGER trg_shift_handover_ride_finished
  AFTER UPDATE OF status ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_shift_handover_ride_finished();

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_poll(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_poll(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_check_rate_limit(uuid, uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_finalize_queued_for_driver(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_finalize_queued_for_driver(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.trg_shift_handover_ride_finished() FROM PUBLIC;
