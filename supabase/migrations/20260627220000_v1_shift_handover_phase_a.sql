-- Phase A: enriched handover notifications, force offline on transfer, email alert.

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_requester_snapshot(p_driver_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'requester_driver_id', d.id,
    'requester_name', NULLIF(
      trim(COALESCE(NULLIF(trim(d.full_name), ''), NULLIF(trim(d.veriff_full_name), ''), 'Chauffeur')),
      ''
    ),
    'profile_photo_url', d.profile_photo_url,
    'rating_stars', ROUND(COALESCE(dts.public_stars, 0)::numeric, 1),
    'member_since', EXTRACT(YEAR FROM d.created_at)::int,
    'verified', (
      COALESCE(d.veriff_status, '') IN ('approved', 'verified')
      OR COALESCE(d.rijbewijs_verified, false)
    )
  )
  FROM public.drivers d
  LEFT JOIN public.driver_trust_scores dts ON dts.driver_id = d.id
  WHERE d.id = p_driver_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_queue_email(
  p_driver_id uuid,
  p_event_type text,
  p_idempotency_key text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF to_regclass('public.driver_email_events') IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(NULLIF(trim(d.email), ''), u.email)
  INTO v_email
  FROM public.drivers d
  LEFT JOIN auth.users u ON u.id = d.user_id
  WHERE d.id = p_driver_id
  LIMIT 1;

  IF v_email IS NULL OR length(trim(v_email)) < 3 THEN
    RETURN;
  END IF;

  INSERT INTO public.driver_email_events (
    driver_id,
    event_type,
    template_id,
    idempotency_key,
    recipient_email,
    payload,
    status
  )
  VALUES (
    p_driver_id,
    p_event_type,
    'shift_handover_security',
    p_idempotency_key,
    v_email,
    COALESCE(p_payload, '{}'::jsonb),
    'queued'
  )
  ON CONFLICT (idempotency_key) DO NOTHING;
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_force_offline_for_handover(
  p_driver_id uuid,
  p_reason text DEFAULT 'shift_handover'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.drivers
  SET status = 'offline'::public.driver_status,
      updated_at = timezone('utc', now())
  WHERE id = p_driver_id
    AND status::text IN ('available', 'on_break', 'on_ride');

  UPDATE public.driver_shift_sessions
  SET is_active = false,
      shift_ended_at = timezone('utc', now())
  WHERE driver_id = p_driver_id
    AND is_active = true;

  UPDATE public.drivers
  SET current_shift_id = NULL
  WHERE id = p_driver_id;
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
  v_plate_label text;
  v_revoke_body text;
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

  v_plate_label := COALESCE(NULLIF(trim(v_req.plate_display), ''), v_req.plate_normalized);

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

  PERFORM public.fn_driver_force_offline_for_handover(v_req.current_driver_id, p_resolution);

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

  IF v_current_user IS NOT NULL AND p_status IN ('approved', 'timed_out') THEN
    IF p_status = 'timed_out' THEN
      v_revoke_body := format(
        'Je dienst op taxi %s is automatisch beëindigd. Een andere chauffeur neemt het over.',
        v_plate_label
      );
    ELSE
      v_revoke_body := format(
        'Je dienst op taxi %s is beëindigd. Een collega neemt de taxi over.',
        v_plate_label
      );
    END IF;

    PERFORM public.fn_driver_shift_handover_notify(
      v_current_user,
      'Taxi toegewezen aan andere chauffeur',
      v_revoke_body,
      'taxi_session_revoked',
      jsonb_build_object(
        'request_id', p_request_id,
        'reason', p_resolution,
        'status', p_status,
        'plate', v_plate_label,
        'plate_normalized', v_req.plate_normalized
      )
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
  v_vehicle public.taxi_vehicles%ROWTYPE;
  v_current_driver_id uuid;
  v_current_user uuid;
  v_grace int;
  v_req_id uuid;
  v_expires timestamptz;
  v_requester jsonb;
  v_requester_name text;
  v_notify_body text;
  v_grace_minutes int;
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
  v_grace_minutes := GREATEST(1, v_grace / 60);

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

  v_requester := COALESCE(
    public.fn_driver_shift_handover_requester_snapshot(v_requester_id),
    '{}'::jsonb
  );
  v_requester_name := COALESCE(v_requester->>'requester_name', 'Een chauffeur');

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

  v_notify_body := format(
    '%s wil Taxi %s besturen. Reageer binnen %s minuten. Geen actie? Je dienst eindigt automatisch.',
    v_requester_name,
    v_plate_display,
    v_grace_minutes
  );

  PERFORM public.fn_driver_shift_handover_notify(
    v_current_user,
    'Dienstwissel aanvraag',
    v_notify_body,
    'shift_handover',
    jsonb_build_object(
      'request_id', v_req_id,
      'vehicle_id', v_vehicle.id,
      'plate', v_plate_norm,
      'plate_display', v_plate_display,
      'expires_at', v_expires,
      'grace_seconds', v_grace
    ) || v_requester
  );

  PERFORM public.fn_driver_shift_handover_queue_email(
    v_current_driver_id,
    'shift_handover_request',
    'shift_handover_email_' || v_req_id::text,
    jsonb_build_object(
      'request_id', v_req_id,
      'plate', v_plate_display,
      'requester_name', v_requester_name,
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
