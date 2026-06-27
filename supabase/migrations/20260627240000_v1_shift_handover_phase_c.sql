-- Phase C: fleet allowlist, private owner alerts, biometric step-up method, admin audit RPCs.

-- ---------------------------------------------------------------------------
-- Staff / fleet authorization helpers (before RLS policies)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_shift_handover_staff_is_authorized()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()
  ) OR EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND coalesce(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role', '')
         IN ('admin', 'super_admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_shift_handover_fleet_can_manage_vehicle(
  p_vehicle_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
  v_vehicle public.taxi_vehicles%ROWTYPE;
BEGIN
  IF public.fn_shift_handover_staff_is_authorized() THEN
    RETURN true;
  END IF;

  SELECT d.id INTO v_actor
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_actor IS NULL THEN
    RETURN false;
  END IF;

  SELECT * INTO v_vehicle
  FROM public.taxi_vehicles tv
  WHERE tv.id = p_vehicle_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_vehicle.ownership_type <> 'shared_fleet' THEN
    RETURN false;
  END IF;

  RETURN v_actor IN (
    v_vehicle.fleet_owner_driver_id,
    v_vehicle.owner_driver_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Fleet allowlist (shared_fleet only; empty = any verified driver)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.taxi_vehicle_driver_allowlist (
  vehicle_id uuid NOT NULL REFERENCES public.taxi_vehicles(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  added_by_driver_id uuid REFERENCES public.drivers(id),
  PRIMARY KEY (vehicle_id, driver_id)
);

CREATE INDEX IF NOT EXISTS idx_taxi_vehicle_driver_allowlist_driver
  ON public.taxi_vehicle_driver_allowlist (driver_id, vehicle_id);

ALTER TABLE public.taxi_vehicle_driver_allowlist ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'taxi_vehicle_driver_allowlist'
      AND policyname = 'taxi_vehicle_allowlist_fleet_read'
  ) THEN
    CREATE POLICY taxi_vehicle_allowlist_fleet_read ON public.taxi_vehicle_driver_allowlist
      FOR SELECT TO authenticated
      USING (
        public.fn_shift_handover_fleet_can_manage_vehicle(vehicle_id)
        OR public.fn_shift_handover_staff_is_authorized()
      );
  END IF;
END $$;

ALTER TABLE public.shift_handover_step_ups
  ADD COLUMN IF NOT EXISTS method text NOT NULL DEFAULT 'otp'
    CHECK (method IN ('otp', 'biometric'));

-- ---------------------------------------------------------------------------
-- Allowlist + notify helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_check_allowlist(
  p_requester_id uuid,
  p_vehicle_id uuid,
  p_ownership_type text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has_rows boolean;
BEGIN
  IF coalesce(p_ownership_type, '') <> 'shared_fleet' THEN
    RETURN jsonb_build_object('ok', true);
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.taxi_vehicle_driver_allowlist av
    WHERE av.vehicle_id = p_vehicle_id
  ) INTO v_has_rows;

  IF NOT v_has_rows THEN
    RETURN jsonb_build_object('ok', true);
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.taxi_vehicle_driver_allowlist av
    WHERE av.vehicle_id = p_vehicle_id
      AND av.driver_id = p_requester_id
  ) THEN
    RETURN jsonb_build_object('ok', true);
  END IF;

  RETURN jsonb_build_object(
    'ok', false,
    'error', 'handover_not_allowlisted',
    'message', 'Je staat niet op de toegestane chauffeurslijst voor deze gedeelde taxi. Neem contact op met de fleetmanager.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_notify_private_owner_attempt(
  p_vehicle_id uuid,
  p_requester_id uuid,
  p_plate_display text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_vehicle public.taxi_vehicles%ROWTYPE;
  v_owner uuid;
  v_owner_user uuid;
  v_requester_name text;
BEGIN
  SELECT * INTO v_vehicle
  FROM public.taxi_vehicles tv
  WHERE tv.id = p_vehicle_id;

  IF NOT FOUND OR v_vehicle.ownership_type <> 'private' THEN
    RETURN;
  END IF;

  v_owner := v_vehicle.owner_driver_id;
  IF v_owner IS NULL OR v_owner = p_requester_id THEN
    RETURN;
  END IF;

  SELECT d.user_id INTO v_owner_user
  FROM public.drivers d
  WHERE d.id = v_owner;

  v_requester_name := COALESCE(
    (public.fn_driver_shift_handover_requester_snapshot(p_requester_id)->>'requester_name'),
    'Een onbekende chauffeur'
  );

  PERFORM public.fn_driver_shift_handover_notify(
    v_owner_user,
    'Poging tot taxi-activering',
    format(
      '%s probeerde je privé-taxi %s te activeren. Was dit verwacht?',
      v_requester_name,
      COALESCE(p_plate_display, v_vehicle.plate_normalized)
    ),
    'shift_handover_private_attempt',
    jsonb_build_object(
      'vehicle_id', p_vehicle_id,
      'requesting_driver_id', p_requester_id,
      'plate', COALESCE(p_plate_display, v_vehicle.plate_normalized)
    )
  );

  PERFORM public.fn_driver_shift_handover_queue_email(
    v_owner,
    'shift_handover_private_attempt',
    'shift_handover_private_' || p_vehicle_id::text || '_' || p_requester_id::text,
    jsonb_build_object(
      'requester_name', v_requester_name,
      'plate', COALESCE(p_plate_display, v_vehicle.plate_normalized)
    )
  );
END;
$$;

DROP FUNCTION IF EXISTS public.fn_driver_shift_handover_issue_step_up();

CREATE OR REPLACE FUNCTION public.fn_driver_shift_handover_issue_step_up(
  p_method text DEFAULT 'otp'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_id uuid;
  v_expires timestamptz;
  v_method text;
BEGIN
  v_method := lower(trim(coalesce(p_method, 'otp')));
  IF v_method NOT IN ('otp', 'biometric') THEN
    v_method := 'otp';
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  v_expires := timezone('utc', now()) + interval '10 minutes';

  INSERT INTO public.shift_handover_step_ups (driver_id, expires_at, method)
  VALUES (v_driver_id, v_expires, v_method)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'ok', true,
    'step_up_id', v_id,
    'expires_at', v_expires,
    'method', v_method
  );
END;
$$;

-- Patch request RPC: allowlist + private owner alert
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
  v_allow jsonb;
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
    jsonb_build_object(
      'ownership_type', v_vehicle.ownership_type,
      'step_up_id', p_step_up_id,
      'step_up_method', (
        SELECT su.method
        FROM public.shift_handover_step_ups su
        WHERE su.id = p_step_up_id
        LIMIT 1
      )
    )
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

-- ---------------------------------------------------------------------------
-- Admin / fleet allowlist management
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_admin_shift_handover_list(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_plate text DEFAULT NULL,
  p_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows jsonb;
  v_total bigint;
BEGIN
  IF NOT public.fn_shift_handover_staff_is_authorized() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  SELECT count(*) INTO v_total
  FROM public.shift_handover_requests shr
  WHERE (p_plate IS NULL OR shr.plate_normalized ILIKE '%' || upper(regexp_replace(trim(p_plate), '[\s\-]', '', 'g')) || '%')
    AND (p_status IS NULL OR shr.status = p_status);

  SELECT coalesce(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.requested_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      shr.id,
      shr.status,
      shr.plate_normalized,
      shr.plate_display,
      shr.requested_at,
      shr.expires_at,
      shr.resolved_at,
      shr.resolution_reason,
      shr.metadata,
      req.full_name AS requesting_name,
      cur.full_name AS current_name
    FROM public.shift_handover_requests shr
    LEFT JOIN public.drivers req ON req.id = shr.requesting_driver_id
    LEFT JOIN public.drivers cur ON cur.id = shr.current_driver_id
    WHERE (p_plate IS NULL OR shr.plate_normalized ILIKE '%' || upper(regexp_replace(trim(p_plate), '[\s\-]', '', 'g')) || '%')
      AND (p_status IS NULL OR shr.status = p_status)
    ORDER BY shr.requested_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
    OFFSET greatest(coalesce(p_offset, 0), 0)
  ) t;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'items', v_rows);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_shift_handover_allowlist_set(
  p_vehicle_id uuid,
  p_driver_id uuid,
  p_add boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF NOT public.fn_shift_handover_fleet_can_manage_vehicle(p_vehicle_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  SELECT d.id INTO v_actor
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF coalesce(p_add, true) THEN
    INSERT INTO public.taxi_vehicle_driver_allowlist (vehicle_id, driver_id, added_by_driver_id)
    VALUES (p_vehicle_id, p_driver_id, v_actor)
    ON CONFLICT (vehicle_id, driver_id) DO NOTHING;
  ELSE
    DELETE FROM public.taxi_vehicle_driver_allowlist
    WHERE vehicle_id = p_vehicle_id AND driver_id = p_driver_id;
  END IF;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_shift_handover_allowlist_list(
  p_vehicle_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.fn_shift_handover_fleet_can_manage_vehicle(p_vehicle_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'items', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'driver_id', av.driver_id,
        'display_name', coalesce(nullif(trim(d.full_name), ''), nullif(trim(d.veriff_full_name), ''), 'Chauffeur'),
        'created_at', av.created_at
      ) ORDER BY av.created_at DESC)
      FROM public.taxi_vehicle_driver_allowlist av
      JOIN public.drivers d ON d.id = av.driver_id
      WHERE av.vehicle_id = p_vehicle_id
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_shift_handover_staff_is_authorized() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_shift_handover_staff_is_authorized() TO authenticated;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_issue_step_up(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_issue_step_up(text) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_admin_shift_handover_list(int, int, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_admin_shift_handover_list(int, int, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_admin_shift_handover_allowlist_set(uuid, uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_admin_shift_handover_allowlist_set(uuid, uuid, boolean) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_admin_shift_handover_allowlist_list(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_admin_shift_handover_allowlist_list(uuid) TO authenticated;
