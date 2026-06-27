-- Phase B: rate limits, fleet notify on deny, rental type, step-up auth.

ALTER TABLE public.taxi_vehicles
  DROP CONSTRAINT IF EXISTS taxi_vehicles_ownership_type_check;

ALTER TABLE public.taxi_vehicles
  ADD CONSTRAINT taxi_vehicles_ownership_type_check
  CHECK (ownership_type IN ('private', 'shared_fleet', 'rental'));

ALTER TABLE public.taxi_vehicles
  ADD COLUMN IF NOT EXISTS fleet_owner_driver_id uuid REFERENCES public.drivers(id);

COMMENT ON COLUMN public.taxi_vehicles.fleet_owner_driver_id IS
  'Fleet manager notified on denied handovers for shared/rental vehicles.';

CREATE TABLE IF NOT EXISTS public.shift_handover_step_ups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_shift_handover_step_ups_driver_active
  ON public.shift_handover_step_ups (driver_id, expires_at DESC)
  WHERE consumed_at IS NULL;

ALTER TABLE public.shift_handover_step_ups ENABLE ROW LEVEL SECURITY;

CREATE POLICY shift_handover_step_ups_select_own ON public.shift_handover_step_ups
  FOR SELECT TO authenticated
  USING (
    driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  );

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_grace_seconds(
  p_ownership_type text DEFAULT 'shared_fleet'
)
RETURNS int
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE COALESCE(NULLIF(trim(p_ownership_type), ''), 'shared_fleet')
    WHEN 'rental' THEN 120
    ELSE 300
  END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_notify_ops(
  p_event text,
  p_detail text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ops_email text;
BEGIN
  PERFORM public.fn_driver_shift_handover_log_security(p_event, p_detail, p_metadata);

  SELECT ac.value INTO v_ops_email
  FROM public.app_config ac
  WHERE ac.key = 'shift_handover_ops_email'
  LIMIT 1;

  IF v_ops_email IS NULL OR length(trim(v_ops_email)) < 3 THEN
    RETURN;
  END IF;

  IF to_regclass('public.driver_email_events') IS NULL THEN
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
    COALESCE((p_metadata->>'requesting_driver_id')::uuid, (SELECT d.id FROM public.drivers d ORDER BY d.created_at ASC LIMIT 1)),
    p_event,
    'shift_handover_ops_alert',
    p_event || '_' || COALESCE(p_metadata->>'request_id', gen_random_uuid()::text),
    v_ops_email,
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('detail', COALESCE(p_detail, '')),
    'queued'
  )
  ON CONFLICT (idempotency_key) DO NOTHING;
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
$$;

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
BEGIN
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
     AND v_last_denied > timezone('utc', now()) - interval '15 minutes' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'handover_cooldown',
      'message', 'De vorige aanvraag is geweigerd. Probeer het over 15 minuten opnieuw.',
      'retry_after', v_last_denied + interval '15 minutes'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_issue_step_up()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_id uuid;
  v_expires timestamptz;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_expires := timezone('utc', now()) + interval '10 minutes';

  INSERT INTO public.shift_handover_step_ups (driver_id, expires_at)
  VALUES (v_driver_id, v_expires)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'ok', true,
    'step_up_id', v_id,
    'expires_at', v_expires
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_consume_step_up(
  p_step_up_id uuid,
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.shift_handover_step_ups%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM public.shift_handover_step_ups
  WHERE id = p_step_up_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_row.driver_id <> p_driver_id
     OR v_row.consumed_at IS NOT NULL
     OR timezone('utc', now()) > v_row.expires_at THEN
    RETURN false;
  END IF;

  UPDATE public.shift_handover_step_ups
  SET consumed_at = timezone('utc', now())
  WHERE id = p_step_up_id;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_notify_fleet_owner(
  p_vehicle_id uuid,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_vehicle public.taxi_vehicles%ROWTYPE;
  v_fleet_owner uuid;
  v_fleet_user uuid;
BEGIN
  SELECT * INTO v_vehicle
  FROM public.taxi_vehicles tv
  WHERE tv.id = p_vehicle_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_vehicle.ownership_type NOT IN ('shared_fleet', 'rental') THEN
    RETURN;
  END IF;

  v_fleet_owner := COALESCE(v_vehicle.fleet_owner_driver_id, v_vehicle.owner_driver_id);
  IF v_fleet_owner IS NULL THEN
    RETURN;
  END IF;

  SELECT d.user_id INTO v_fleet_user
  FROM public.drivers d
  WHERE d.id = v_fleet_owner;

  PERFORM public.fn_driver_shift_handover_notify(
    v_fleet_user,
    p_title,
    p_body,
    'shift_handover_fleet',
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('vehicle_id', p_vehicle_id)
  );
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
  v_grace_minutes int;
  v_rate jsonb;
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
      'message', 'Bevestig je identiteit met een eenmalige code voordat je een dienstwissel aanvraagt.'
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

  v_grace := public.fn_driver_shift_handover_grace_seconds(v_vehicle.ownership_type);
  v_grace_minutes := GREATEST(1, v_grace / 60);

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

  v_expires := timezone('utc', now()) + make_interval(secs => v_grace);

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
    jsonb_build_object('ownership_type', v_vehicle.ownership_type, 'step_up_id', p_step_up_id)
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
      'grace_seconds', v_grace,
      'ownership_type', v_vehicle.ownership_type
    ) || v_requester_snapshot
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
      'current_driver_id', v_current_driver_id,
      'ownership_type', v_vehicle.ownership_type
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
  v_requester_name text;
  v_action text;
  v_deny_count int;
  v_vehicle public.taxi_vehicles%ROWTYPE;
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

    SELECT * INTO v_vehicle FROM public.taxi_vehicles tv WHERE tv.id = v_req.vehicle_id;

    v_requester_name := COALESCE(
      (public.fn_driver_shift_handover_requester_snapshot(v_req.requesting_driver_id)->>'requester_name'),
      'Een chauffeur'
    );

    PERFORM public.fn_driver_shift_handover_notify_fleet_owner(
      v_req.vehicle_id,
      'Dienstwissel geweigerd',
      format(
        '%s probeerde Taxi %s te starten. De huidige chauffeur rijdt nog. Was dit verwacht?',
        v_requester_name,
        COALESCE(v_req.plate_display, v_req.plate_normalized)
      ),
      jsonb_build_object(
        'request_id', p_request_id,
        'requesting_driver_id', v_req.requesting_driver_id,
        'current_driver_id', v_req.current_driver_id,
        'plate', v_req.plate_normalized
      )
    );

    SELECT count(*) INTO v_deny_count
    FROM public.shift_handover_requests shr
    WHERE shr.requesting_driver_id = v_req.requesting_driver_id
      AND shr.vehicle_id = v_req.vehicle_id
      AND shr.status = 'denied'
      AND shr.resolved_at > timezone('utc', now()) - interval '24 hours';

    PERFORM public.fn_driver_shift_handover_log_security(
      'shift_handover_denied',
      v_req.plate_normalized,
      jsonb_build_object(
        'request_id', p_request_id,
        'current_driver_id', v_actor_id,
        'deny_count_24h', v_deny_count
      )
    );

    IF v_deny_count >= 2 THEN
      PERFORM public.fn_driver_shift_handover_notify_ops(
        'shift_handover_rate_blocked',
        v_req.plate_normalized,
        jsonb_build_object(
          'request_id', p_request_id,
          'requesting_driver_id', v_req.requesting_driver_id,
          'vehicle_id', v_req.vehicle_id,
          'deny_count_24h', v_deny_count
        )
      );
    END IF;

    RETURN jsonb_build_object('ok', true, 'status', 'denied', 'request_id', p_request_id);
  END IF;

  RETURN jsonb_build_object('ok', false, 'error', 'invalid_action');
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_issue_step_up() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_issue_step_up() TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_request(text, text, jsonb, text, uuid) TO authenticated;
