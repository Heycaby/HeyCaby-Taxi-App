-- Secure shift handover: 5-minute grace window before automatic session transfer.

ALTER TABLE public.taxi_vehicles
  ADD COLUMN IF NOT EXISTS ownership_type text NOT NULL DEFAULT 'shared_fleet'
    CHECK (ownership_type IN ('private', 'shared_fleet')),
  ADD COLUMN IF NOT EXISTS owner_driver_id uuid REFERENCES public.drivers(id);

COMMENT ON COLUMN public.taxi_vehicles.ownership_type IS
  'private = only owner_driver_id may activate; shared_fleet = secure handover flow.';
COMMENT ON COLUMN public.taxi_vehicles.owner_driver_id IS
  'Registered owner for private taxis; NULL for shared/fleet vehicles.';

CREATE TABLE IF NOT EXISTS public.shift_handover_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES public.taxi_vehicles(id) ON DELETE CASCADE,
  requesting_driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  current_driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending', 'approved', 'denied', 'timed_out', 'cancelled',
      'blocked_private', 'blocked_active_ride'
    )),
  plate_normalized text NOT NULL,
  plate_display text,
  rdw_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  vehicle_verification_status text NOT NULL DEFAULT 'rdw_verified_taxi',
  requested_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  expires_at timestamptz NOT NULL,
  resolved_at timestamptz,
  resolution_reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT shift_handover_requests_distinct_drivers
    CHECK (requesting_driver_id <> current_driver_id)
);

CREATE INDEX IF NOT EXISTS idx_shift_handover_requests_pending
  ON public.shift_handover_requests (vehicle_id, status, expires_at DESC)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_shift_handover_requests_requesting
  ON public.shift_handover_requests (requesting_driver_id, requested_at DESC);

ALTER TABLE public.shift_handover_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY shift_handover_requests_select_participant ON public.shift_handover_requests
  FOR SELECT TO authenticated
  USING (
    requesting_driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
    OR current_driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_grace_seconds()
RETURNS int
LANGUAGE sql
IMMUTABLE
AS $$ SELECT 300; $$; -- 5 minutes

CREATE OR REPLACE FUNCTION public.fn_driver_has_active_ride(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.driver_id = p_driver_id
      AND rr.status IN (
        'accepted', 'assigned', 'driver_arrived', 'driver_en_route',
        'in_progress', 'arrived'
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_log_security(
  p_event text,
  p_detail text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.fn_driver_log_client_telemetry(
    'security',
    p_event,
    COALESCE(p_detail, '')
  );
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_notify(
  p_target_auth_user_id uuid,
  p_title text,
  p_body text,
  p_category text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_target_auth_user_id IS NULL THEN
    RETURN NULL;
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
  )
  VALUES (
    'driver',
    p_target_auth_user_id::text,
    'shift_handover',
    p_category,
    p_title,
    p_body,
    COALESCE(p_data, '{}'::jsonb),
    'critical',
    'both'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_finalize(
  p_request_id uuid,
  p_resolution text,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.shift_handover_requests%ROWTYPE;
  v_verification_status public.vehicle_verification_status;
  v_requester_user uuid;
  v_current_user uuid;
BEGIN
  SELECT * INTO v_req
  FROM public.shift_handover_requests shr
  WHERE shr.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'status', v_req.status,
      'already_resolved', true,
      'request_id', v_req.id
    );
  END IF;

  v_verification_status := COALESCE(
    NULLIF(trim(v_req.vehicle_verification_status), ''),
    'rdw_verified_taxi'
  )::public.vehicle_verification_status;

  UPDATE public.taxi_vehicle_sessions
  SET is_active = false,
      ended_at = timezone('utc', now()),
      ended_reason = p_resolution
  WHERE vehicle_id = v_req.vehicle_id
    AND is_active = true
    AND ended_at IS NULL
    AND driver_id = v_req.current_driver_id;

  UPDATE public.taxi_vehicles
  SET is_shared_fleet = true,
      ownership_type = 'shared_fleet',
      updated_at = timezone('utc', now())
  WHERE id = v_req.vehicle_id;

  UPDATE public.drivers d
  SET vehicle_plate = v_req.plate_normalized,
      vehicle_plate_entered = COALESCE(v_req.plate_display, v_req.plate_normalized),
      taxi_vehicle_id = v_req.vehicle_id,
      vehicle_verification_status = v_verification_status,
      rdw_merk = COALESCE(v_req.rdw_snapshot->>'merk', d.rdw_merk),
      rdw_handelsbenaming = COALESCE(v_req.rdw_snapshot->>'handelsbenaming', d.rdw_handelsbenaming),
      rdw_voertuigsoort = COALESCE(v_req.rdw_snapshot->>'voertuigsoort', d.rdw_voertuigsoort),
      rdw_eerste_kleur = COALESCE(v_req.rdw_snapshot->>'eerste_kleur', d.rdw_eerste_kleur),
      rdw_apk_vervaldatum = COALESCE(v_req.rdw_snapshot->>'vervaldatum_apk', d.rdw_apk_vervaldatum),
      updated_at = timezone('utc', now())
  WHERE d.id = v_req.requesting_driver_id;

  UPDATE public.taxi_vehicle_sessions
  SET is_active = false,
      ended_at = timezone('utc', now()),
      ended_reason = 'replaced'
  WHERE driver_id = v_req.requesting_driver_id
    AND is_active = true
    AND ended_at IS NULL;

  INSERT INTO public.taxi_vehicle_sessions (vehicle_id, driver_id, is_active)
  VALUES (v_req.vehicle_id, v_req.requesting_driver_id, true);

  UPDATE public.shift_handover_requests
  SET status = p_status,
      resolved_at = timezone('utc', now()),
      resolution_reason = p_resolution,
      metadata = metadata || jsonb_build_object('finalized_at', timezone('utc', now()))
  WHERE id = p_request_id;

  SELECT d.user_id INTO v_requester_user FROM public.drivers d WHERE d.id = v_req.requesting_driver_id;
  SELECT d.user_id INTO v_current_user FROM public.drivers d WHERE d.id = v_req.current_driver_id;

  PERFORM public.fn_driver_shift_handover_notify(
    v_requester_user,
    'Dienst gestart',
    'Je kunt doorgaan met online gaan.',
    'shift_handover_complete',
    jsonb_build_object('request_id', p_request_id, 'status', p_status)
  );

  IF v_current_user IS NOT NULL AND p_status = 'approved' THEN
    PERFORM public.fn_driver_shift_handover_notify(
      v_current_user,
      'Dienst beëindigd',
      'Een collega heeft de taxi overgenomen.',
      'shift_handover_ended',
      jsonb_build_object('request_id', p_request_id)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', p_status,
    'request_id', p_request_id,
    'plate', v_req.plate_normalized,
    'vehicle_id', v_req.vehicle_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Request handover (waiting driver)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_request(
  p_vehicle_plate text,
  p_vehicle_plate_entered text DEFAULT NULL,
  p_rdw_snapshot jsonb DEFAULT '{}'::jsonb,
  p_vehicle_verification_status text DEFAULT 'rdw_verified_taxi'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_id uuid;
  v_plate_norm text;
  v_plate_display text;
  v_vehicle_id uuid;
  v_vehicle public.taxi_vehicles%ROWTYPE;
  v_current_driver_id uuid;
  v_current_user uuid;
  v_grace int;
  v_req_id uuid;
  v_expires timestamptz;
BEGIN
  SELECT d.id INTO v_requester_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_requester_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_plate_norm := upper(regexp_replace(trim(p_vehicle_plate), '[\s\-]', '', 'g'));
  v_plate_display := COALESCE(NULLIF(trim(p_vehicle_plate_entered), ''), v_plate_norm);
  IF length(v_plate_norm) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_plate');
  END IF;

  v_grace := public.fn_driver_shift_handover_grace_seconds();

  SELECT tv.* INTO v_vehicle
  FROM public.taxi_vehicles tv
  WHERE tv.plate_normalized = v_plate_norm
  LIMIT 1;

  IF v_vehicle.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'vehicle_not_registered', 'direct_claim', true);
  END IF;

  IF v_vehicle.ownership_type = 'private'
     AND v_vehicle.owner_driver_id IS NOT NULL
     AND v_vehicle.owner_driver_id <> v_requester_id THEN
    PERFORM public.fn_driver_shift_handover_log_security(
      'shift_handover_private_blocked',
      v_plate_norm,
      jsonb_build_object('vehicle_id', v_vehicle.id, 'owner_driver_id', v_vehicle.owner_driver_id)
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'private_taxi_owner_only',
      'message', 'Deze taxi is privé geregistreerd en kan niet door andere chauffeurs worden geactiveerd.'
    );
  END IF;

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

  IF public.fn_driver_has_active_ride(v_current_driver_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'active_ride_in_progress',
      'message', 'Deze taxi is bezig met een rit. Probeer het opnieuw zodra de rit is afgerond.'
    );
  END IF;

  UPDATE public.shift_handover_requests
  SET status = 'cancelled',
      resolved_at = timezone('utc', now()),
      resolution_reason = 'superseded'
  WHERE requesting_driver_id = v_requester_id
    AND vehicle_id = v_vehicle.id
    AND status = 'pending';

  v_expires := timezone('utc', now()) + make_interval(secs => v_grace);

  INSERT INTO public.shift_handover_requests (
    vehicle_id,
    requesting_driver_id,
    current_driver_id,
    plate_normalized,
    plate_display,
    rdw_snapshot,
    vehicle_verification_status,
    expires_at
  )
  VALUES (
    v_vehicle.id,
    v_requester_id,
    v_current_driver_id,
    v_plate_norm,
    v_plate_display,
    COALESCE(p_rdw_snapshot, '{}'::jsonb),
    COALESCE(NULLIF(trim(p_vehicle_verification_status), ''), 'rdw_verified_taxi'),
    v_expires
  )
  RETURNING id INTO v_req_id;

  SELECT d.user_id INTO v_current_user
  FROM public.drivers d
  WHERE d.id = v_current_driver_id;

  PERFORM public.fn_driver_shift_handover_notify(
    v_current_user,
    'Iemand wil met deze taxi starten',
    'Als dit je dienstwissel is hoef je niets te doen. Verwacht je dit niet? Tik op Ik rij nog.',
    'shift_handover',
    jsonb_build_object(
      'request_id', v_req_id,
      'vehicle_id', v_vehicle.id,
      'plate', v_plate_norm,
      'expires_at', v_expires
    )
  );

  PERFORM public.fn_driver_shift_handover_log_security(
    'shift_handover_requested',
    v_plate_norm,
    jsonb_build_object(
      'request_id', v_req_id,
      'requesting_driver_id', v_requester_id,
      'current_driver_id', v_current_driver_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'request_id', v_req_id,
    'status', 'pending',
    'expires_at', v_expires,
    'grace_seconds', v_grace
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Current driver responds
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_respond(
  p_request_id uuid,
  p_action text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.shift_handover_requests%ROWTYPE;
  v_actor_id uuid;
  v_requester_user uuid;
  v_action text;
BEGIN
  v_action := lower(trim(COALESCE(p_action, '')));

  SELECT d.id INTO v_actor_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_req
  FROM public.shift_handover_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF v_req.current_driver_id <> v_actor_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'status', v_req.status, 'already_resolved', true);
  END IF;

  SELECT d.user_id INTO v_requester_user
  FROM public.drivers d
  WHERE d.id = v_req.requesting_driver_id;

  IF v_action IN ('approve', 'end_shift', 'end') THEN
    RETURN public.fn_driver_shift_handover_finalize(p_request_id, 'shift_handover', 'approved');
  END IF;

  IF v_action IN ('deny', 'still_driving', 'deny_still_driving') THEN
    UPDATE public.shift_handover_requests
    SET status = 'denied',
        resolved_at = timezone('utc', now()),
        resolution_reason = 'denied_by_current_driver',
        metadata = metadata || jsonb_build_object('denied_by', v_actor_id)
    WHERE id = p_request_id;

    PERFORM public.fn_driver_shift_handover_notify(
      v_requester_user,
      'Taxi nog in gebruik',
      'De huidige chauffeur rijdt nog met deze taxi.',
      'shift_handover_denied',
      jsonb_build_object('request_id', p_request_id)
    );

    PERFORM public.fn_driver_shift_handover_log_security(
      'shift_handover_denied',
      v_req.plate_normalized,
      jsonb_build_object('request_id', p_request_id, 'current_driver_id', v_actor_id)
    );

    RETURN jsonb_build_object('ok', true, 'status', 'denied', 'request_id', p_request_id);
  END IF;

  RETURN jsonb_build_object('ok', false, 'error', 'invalid_action');
END;
$$;

-- ---------------------------------------------------------------------------
-- Poll (requesting driver) — processes timeout
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_poll(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.shift_handover_requests%ROWTYPE;
  v_requester_id uuid;
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

  IF v_req.status = 'pending' AND timezone('utc', now()) >= v_req.expires_at THEN
    IF public.fn_driver_has_active_ride(v_req.current_driver_id) THEN
      UPDATE public.shift_handover_requests
      SET status = 'blocked_active_ride',
          resolved_at = timezone('utc', now()),
          resolution_reason = 'active_ride_at_timeout'
      WHERE id = p_request_id;
      RETURN jsonb_build_object(
        'ok', false,
        'status', 'blocked_active_ride',
        'error', 'active_ride_in_progress',
        'request_id', p_request_id
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
    'plate', v_req.plate_normalized,
    'vehicle_id', v_req.vehicle_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- claim_plate: block immediate takeover — use handover RPC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_onboarding_v2_claim_plate(
  p_user_id uuid,
  p_vehicle_plate text,
  p_vehicle_plate_entered text DEFAULT NULL,
  p_rdw_snapshot jsonb DEFAULT '{}'::jsonb,
  p_vehicle_verification_status text DEFAULT 'rdw_verified_taxi',
  p_shared_fleet_ack boolean DEFAULT false,
  p_confirm_shift_start boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_plate_norm text;
  v_plate_display text;
  v_vehicle_id uuid;
  v_other_driver uuid;
  v_active_session_driver uuid;
  v_active_session jsonb;
  v_verification_status public.vehicle_verification_status;
  v_shift_ack boolean;
BEGIN
  v_shift_ack := COALESCE(p_confirm_shift_start, p_shared_fleet_ack, false);

  IF p_user_id IS NULL OR p_vehicle_plate IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_input');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  v_plate_norm := upper(regexp_replace(trim(p_vehicle_plate), '[\s\-]', '', 'g'));
  v_plate_display := COALESCE(NULLIF(trim(p_vehicle_plate_entered), ''), v_plate_norm);
  IF length(v_plate_norm) < 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_plate');
  END IF;

  v_verification_status := COALESCE(
    NULLIF(trim(p_vehicle_verification_status), ''),
    'rdw_verified_taxi'
  )::public.vehicle_verification_status;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = p_user_id
  LIMIT 1;
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
  END IF;

  SELECT tv.id INTO v_vehicle_id
  FROM public.taxi_vehicles tv
  WHERE tv.plate_normalized = v_plate_norm
  LIMIT 1;

  v_active_session := NULL;

  IF v_vehicle_id IS NOT NULL THEN
    SELECT
      tvs.driver_id,
      jsonb_build_object(
        'started_at', tvs.started_at,
        'status_label', CASE
          WHEN d.status::text IN ('available', 'on_ride') THEN 'online'
          ELSE 'offline'
        END
      )
    INTO v_active_session_driver, v_active_session
    FROM public.taxi_vehicle_sessions tvs
    JOIN public.drivers d ON d.id = tvs.driver_id
    WHERE tvs.vehicle_id = v_vehicle_id
      AND tvs.is_active = true
      AND tvs.ended_at IS NULL
      AND tvs.driver_id <> v_driver_id
    LIMIT 1;

    IF v_active_session_driver IS NOT NULL THEN
      IF v_shift_ack THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'shift_handover_required',
          'shift_start_prompt', true,
          'shared_prompt', true
        );
      END IF;
      RETURN jsonb_build_object(
        'success', false,
        'error', 'vehicle_session_active',
        'shared_prompt', true,
        'shift_start_prompt', true,
        'active_session', v_active_session
      );
    END IF;
  ELSE
    INSERT INTO public.taxi_vehicles (
      plate_normalized,
      plate_display,
      rdw_snapshot,
      owner_driver_id,
      ownership_type
    )
    VALUES (
      v_plate_norm,
      v_plate_display,
      COALESCE(p_rdw_snapshot, '{}'::jsonb),
      v_driver_id,
      'private'
    )
    RETURNING id INTO v_vehicle_id;
  END IF;

  SELECT d.id INTO v_other_driver
  FROM public.drivers d
  WHERE upper(regexp_replace(trim(COALESCE(d.vehicle_plate, '')), '[\s\-]', '', 'g')) = v_plate_norm
    AND d.id <> v_driver_id
  LIMIT 1;

  IF v_other_driver IS NOT NULL AND NOT v_shift_ack THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'plate_linked',
      'shared_prompt', true,
      'shift_start_prompt', true,
      'active_session', NULL
    );
  END IF;

  IF v_other_driver IS NOT NULL AND v_shift_ack THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'shift_handover_required',
      'shift_start_prompt', true,
      'shared_prompt', true
    );
  END IF;

  UPDATE public.drivers d
  SET vehicle_plate = v_plate_norm,
      vehicle_plate_entered = v_plate_display,
      taxi_vehicle_id = v_vehicle_id,
      vehicle_verification_status = v_verification_status,
      rdw_merk = COALESCE(p_rdw_snapshot->>'merk', d.rdw_merk),
      rdw_handelsbenaming = COALESCE(p_rdw_snapshot->>'handelsbenaming', d.rdw_handelsbenaming),
      rdw_voertuigsoort = COALESCE(p_rdw_snapshot->>'voertuigsoort', d.rdw_voertuigsoort),
      rdw_eerste_kleur = COALESCE(p_rdw_snapshot->>'eerste_kleur', d.rdw_eerste_kleur),
      rdw_apk_vervaldatum = COALESCE(p_rdw_snapshot->>'vervaldatum_apk', d.rdw_apk_vervaldatum),
      updated_at = timezone('utc', now())
  WHERE d.id = v_driver_id;

  UPDATE public.taxi_vehicle_sessions
  SET is_active = false,
      ended_at = timezone('utc', now()),
      ended_reason = 'replaced'
  WHERE driver_id = v_driver_id
    AND is_active = true
    AND ended_at IS NULL;

  INSERT INTO public.taxi_vehicle_sessions (vehicle_id, driver_id, is_active)
  VALUES (v_vehicle_id, v_driver_id, true);

  RETURN jsonb_build_object(
    'success', true,
    'vehicle_id', v_vehicle_id,
    'plate', v_plate_norm
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'plate_conflict',
      'shared_prompt', true,
      'shift_start_prompt', true,
      'active_session', NULL
    );
  WHEN invalid_text_representation THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_verification_status'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_respond(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_respond(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_poll(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_poll(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_onboarding_v2_claim_plate(uuid, text, text, jsonb, text, boolean, boolean) TO authenticated;
