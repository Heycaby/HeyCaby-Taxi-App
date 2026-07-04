-- Secure Shift Handover UX hardening:
-- Return structured readiness blockers instead of a generic verification error.

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
  v_readiness jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_primary_blocker text;
BEGIN
  SELECT d.* INTO v_requester_driver
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  v_requester_id := v_requester_driver.id;

  IF v_requester_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_readiness := public.fn_driver_runtime_permissions(v_requester_id);

  IF COALESCE((v_readiness->>'can_go_online')::boolean, false) IS NOT TRUE THEN
    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb)
    INTO v_missing
    FROM jsonb_array_elements(COALESCE(v_readiness->'checklist', '[]'::jsonb)) item
    WHERE COALESCE((item->>'complete')::boolean, false) IS NOT TRUE
      AND item->>'key' IN (
        SELECT jsonb_array_elements_text(
          COALESCE(v_readiness->'missing_docs', '[]'::jsonb)
        )
      );

    SELECT item->>'key'
    INTO v_primary_blocker
    FROM jsonb_array_elements(v_missing) item
    LIMIT 1;

    RETURN jsonb_build_object(
      'ok', false,
      'error', 'handover_not_eligible',
      'blocked_reason', COALESCE(v_primary_blocker, 'requirements_missing'),
      'message', 'Complete the missing requirements before taking over this taxi.',
      'readiness', v_readiness,
      'missing_requirements', v_missing
    );
  END IF;

  IF p_step_up_id IS NULL
     OR NOT public.fn_driver_shift_handover_consume_step_up(p_step_up_id, v_requester_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'step_up_required',
      'message', 'Confirm your identity before requesting Secure Shift Handover.'
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
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'vehicle_not_registered',
      'direct_claim', true
    );
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
      jsonb_build_object(
        'vehicle_id', v_vehicle.id,
        'requesting_driver_id', v_requester_id
      )
    );
    RETURN v_allow;
  END IF;

  IF v_vehicle.ownership_type = 'private'
     AND v_vehicle.owner_driver_id IS NOT NULL
     AND v_vehicle.owner_driver_id <> v_requester_id THEN
    PERFORM public.fn_driver_shift_handover_log_security(
      'shift_handover_private_blocked',
      v_plate_norm,
      jsonb_build_object(
        'vehicle_id', v_vehicle.id,
        'owner_driver_id', v_vehicle.owner_driver_id
      )
    );
    PERFORM public.fn_driver_shift_handover_notify_private_owner_attempt(
      v_vehicle.id,
      v_requester_id,
      v_plate_display
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'private_taxi_owner_only',
      'message', 'This taxi is privately registered and cannot be activated by other drivers.'
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
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'no_active_session',
      'direct_claim', true
    );
  END IF;

  v_has_active_ride := public.fn_driver_has_active_ride(v_current_driver_id);

  v_requester_snapshot := COALESCE(
    public.fn_driver_shift_handover_requester_snapshot(v_requester_id),
    '{}'::jsonb
  );
  v_requester_name := COALESCE(v_requester_snapshot->>'requester_name', 'A driver');

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
      'queued_reason', CASE
        WHEN v_has_active_ride THEN 'current_driver_active_ride'
        ELSE NULL
      END
    )
  )
  RETURNING id INTO v_req_id;

  SELECT d.user_id INTO v_current_user
  FROM public.drivers d
  WHERE d.id = v_current_driver_id;

  IF v_has_active_ride THEN
    v_notify_body := format(
      '%s wants to take over taxi %s after your current ride. The shift handover is queued until the ride is complete.',
      v_requester_name,
      v_plate_display
    );

    PERFORM public.fn_driver_shift_handover_notify(
      v_current_user,
      'Shift handover after current ride',
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
      '%s wants to drive taxi %s. Respond within 2 minutes. No action means your shift ends automatically.',
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
    CASE
      WHEN v_has_active_ride THEN 'shift_handover_queued'
      ELSE 'shift_handover_request'
    END,
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
    CASE
      WHEN v_has_active_ride THEN 'shift_handover_queued_active_ride'
      ELSE 'shift_handover_requested'
    END,
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

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid)
  IS 'Requests secure shift handover and returns structured readiness blockers before step-up when the requesting driver is not operationally eligible.';
