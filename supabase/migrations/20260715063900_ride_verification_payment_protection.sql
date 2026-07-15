-- Ride Verification and Payment Protection Layer
-- Additive and fail-closed. All rollout flags default to false, so the
-- established lifecycle remains unchanged until an explicit cohort rollout.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

UPDATE public.app_config
SET value = (
  COALESCE(NULLIF(value, '')::jsonb, '{}'::jsonb) || jsonb_build_object(
    'ride_arrival_verification_enabled', false,
    'pickup_locking_enabled', false,
    'boarding_pin_enabled', false,
    'route_evidence_enabled', false,
    'verified_completion_enabled', false,
    'payment_evidence_gate_enabled', false
  )
)::text
WHERE key = 'feature_flags';

INSERT INTO public.app_config(key, value)
VALUES (
  'ride_verification_config',
  jsonb_build_object(
    'pickup_edit_lock_distance_meters', 500,
    'pickup_edit_lock_eta_minutes', 3,
    'maximum_pickup_changes', 3,
    'maximum_pickup_change_distance_meters', 2000,
    'arrival_geofence_meters', 150,
    'arrival_max_gps_accuracy_meters', 65,
    'arrival_max_speed_kmh', 8,
    'arrival_dwell_seconds', 60,
    'location_max_age_seconds', 90,
    'boarding_pin_digits', 6,
    'boarding_pin_ttl_minutes', 30,
    'boarding_pin_max_attempts', 5,
    'destination_geofence_meters', 250,
    'completion_min_duration_seconds', 120,
    'completion_min_distance_meters', 100,
    'completion_confirmation_grace_seconds', 120,
    'no_show_wait_seconds', 300,
    'route_max_plausible_speed_kmh', 190,
    'route_sample_retention_days', 90
  )::text
)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.ride_verification_state (
  ride_id uuid PRIMARY KEY REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  protected boolean NOT NULL DEFAULT false,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  pickup_version integer NOT NULL DEFAULT 1 CHECK (pickup_version > 0),
  pickup_locked_at timestamptz,
  arrival_requested_at timestamptz,
  arrival_first_valid_sample_at timestamptz,
  arrival_verified boolean NOT NULL DEFAULT false,
  arrival_verified_at timestamptz,
  arrival_lat double precision CHECK (arrival_lat IS NULL OR arrival_lat BETWEEN -90 AND 90),
  arrival_lng double precision CHECK (arrival_lng IS NULL OR arrival_lng BETWEEN -180 AND 180),
  arrival_accuracy_m double precision,
  waiting_timer_started_at timestamptz,
  boarding_pin_hash text,
  boarding_pin_salt text,
  boarding_pin_expires_at timestamptz,
  boarding_pin_failed_attempts integer NOT NULL DEFAULT 0 CHECK (boarding_pin_failed_attempts >= 0),
  boarding_pin_consumed_at timestamptz,
  boarding_verified boolean NOT NULL DEFAULT false,
  boarding_verified_at timestamptz,
  boarding_verification_method text CHECK (
    boarding_verification_method IS NULL OR
    boarding_verification_method IN ('pin','rider_confirmation','support_override')
  ),
  started_verified_at timestamptz,
  start_lat double precision,
  start_lng double precision,
  destination_arrival_requested_at timestamptz,
  destination_arrival_verified_at timestamptz,
  destination_arrival_lat double precision,
  destination_arrival_lng double precision,
  rider_completion_confirmed_at timestamptz,
  completion_verified boolean NOT NULL DEFAULT false,
  completion_verified_at timestamptz,
  risk_status text NOT NULL DEFAULT 'clear' CHECK (risk_status IN ('clear','review_required','blocked')),
  risk_reasons jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(risk_reasons) = 'array'),
  payment_eligible_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- The retrievable PIN is isolated from the state table, denied to every app
-- role, and only released by the rider snapshot RPC. Verification compares a
-- salted digest; drivers and direct PostgREST reads can never access the code.
CREATE TABLE IF NOT EXISTS public.ride_boarding_secrets (
  ride_id uuid PRIMARY KEY REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  pin_code text NOT NULL CHECK (pin_code ~ '^[0-9]{4,6}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ride_pickup_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  version integer NOT NULL CHECK (version > 0),
  latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  address text NOT NULL,
  actor_type text NOT NULL CHECK (actor_type IN ('rider','driver','admin','system')),
  actor_id uuid,
  change_reason text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_id, version)
);

CREATE TABLE IF NOT EXISTS public.ride_pickup_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  from_version integer NOT NULL,
  requested_lat double precision NOT NULL CHECK (requested_lat BETWEEN -90 AND 90),
  requested_lng double precision NOT NULL CHECK (requested_lng BETWEEN -180 AND 180),
  requested_address text NOT NULL,
  distance_delta_m integer NOT NULL CHECK (distance_delta_m >= 0),
  estimated_delay_seconds integer,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','expired')),
  requested_by uuid,
  requested_at timestamptz NOT NULL DEFAULT now(),
  responded_by uuid,
  responded_at timestamptz,
  response_reason text
);
CREATE UNIQUE INDEX IF NOT EXISTS ride_pickup_one_pending_change_idx
  ON public.ride_pickup_change_requests(ride_id) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS public.ride_contact_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  actor_type text NOT NULL CHECK (actor_type IN ('rider','driver','system','admin')),
  actor_id uuid,
  channel text NOT NULL CHECK (channel IN ('chat','masked_call','push','support')),
  outcome text,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ride_protection_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE RESTRICT,
  case_type text NOT NULL CHECK (case_type IN (
    'end_trip_early','report_driver','safety_incident','payment_dispute',
    'refund_request','completion_review','support_override'
  )),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewing','resolved','rejected')),
  opened_by_type text NOT NULL CHECK (opened_by_type IN ('rider','driver','admin','system')),
  opened_by uuid,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 3 AND 2000),
  resolution text,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid
);

CREATE TABLE IF NOT EXISTS public.ride_verification_commands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  command text NOT NULL,
  actor_id uuid,
  idempotency_key uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_id, command, actor_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS ride_verification_review_idx
  ON public.ride_verification_state(risk_status, updated_at DESC)
  WHERE risk_status <> 'clear';
CREATE INDEX IF NOT EXISTS ride_pickup_versions_timeline_idx
  ON public.ride_pickup_versions(ride_id, version);
CREATE INDEX IF NOT EXISTS ride_contact_attempts_timeline_idx
  ON public.ride_contact_attempts(ride_id, occurred_at);
CREATE INDEX IF NOT EXISTS ride_protection_cases_open_idx
  ON public.ride_protection_cases(status, created_at DESC);

ALTER TABLE public.ride_verification_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_boarding_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_pickup_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_pickup_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_contact_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_protection_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_verification_commands ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION private.trg_reject_ride_evidence_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'ride_evidence_is_append_only' USING ERRCODE = '55000';
END; $$;
DROP TRIGGER IF EXISTS trg_ride_pickup_versions_append_only ON public.ride_pickup_versions;
CREATE TRIGGER trg_ride_pickup_versions_append_only BEFORE UPDATE OR DELETE ON public.ride_pickup_versions
FOR EACH ROW EXECUTE FUNCTION private.trg_reject_ride_evidence_mutation();
DROP TRIGGER IF EXISTS trg_ride_contact_attempts_append_only ON public.ride_contact_attempts;
CREATE TRIGGER trg_ride_contact_attempts_append_only BEFORE UPDATE OR DELETE ON public.ride_contact_attempts
FOR EACH ROW EXECUTE FUNCTION private.trg_reject_ride_evidence_mutation();

REVOKE ALL ON TABLE public.ride_verification_state FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ride_boarding_secrets FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ride_pickup_versions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ride_pickup_change_requests FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ride_contact_attempts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ride_protection_cases FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ride_verification_commands FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.ride_verification_state, public.ride_boarding_secrets,
  public.ride_pickup_versions, public.ride_pickup_change_requests,
  public.ride_contact_attempts, public.ride_protection_cases,
  public.ride_verification_commands TO service_role;

CREATE OR REPLACE FUNCTION private.fn_ride_verification_config()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v jsonb;
BEGIN
  BEGIN
    SELECT COALESCE(NULLIF(value, '')::jsonb, '{}'::jsonb) INTO v
    FROM public.app_config WHERE key = 'ride_verification_config';
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'ride_verification_config_invalid' USING ERRCODE = '22023';
  END;
  RETURN COALESCE(v, '{}'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION private.fn_ride_verification_flag(p_name text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v jsonb;
BEGIN
  BEGIN
    SELECT COALESCE(NULLIF(value, '')::jsonb, '{}'::jsonb) INTO v
    FROM public.app_config WHERE key = 'feature_flags';
  EXCEPTION WHEN OTHERS THEN RETURN false;
  END;
  RETURN COALESCE((v ->> p_name)::boolean, false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END; $$;

CREATE OR REPLACE FUNCTION private.fn_ride_is_payment_protected(p_ride_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.ride_payments rp
    WHERE rp.ride_id = p_ride_id
      AND rp.state IN ('paid','routing_pending','routing_failed','routed','partially_refunded')
      AND rp.paid_at IS NOT NULL
      AND rp.refunded_cents < rp.amount_cents
  );
$$;

CREATE OR REPLACE FUNCTION private.fn_ride_rider_authorized(
  p_ride public.ride_requests, p_rider_token text
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = '' AS $$
  SELECT
    (p_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = p_ride.rider_identity_id AND ri.user_id = auth.uid()
    ))
    OR (NULLIF(btrim(COALESCE(p_rider_token, '')), '') IS NOT NULL
        AND p_ride.rider_token = btrim(p_rider_token))
    OR (auth.uid() IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid() AND rs.session_token = p_ride.rider_token
    ));
$$;

CREATE OR REPLACE FUNCTION private.fn_ride_driver_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.fn_ensure_ride_verification(p_ride_id uuid)
RETURNS public.ride_verification_state LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '' AS $$
DECLARE v public.ride_verification_state; r public.ride_requests%ROWTYPE;
DECLARE v_lat double precision; v_lng double precision;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id = p_ride_id;
  IF r.id IS NULL THEN RAISE EXCEPTION 'ride_not_found'; END IF;
  INSERT INTO public.ride_verification_state(ride_id, protected)
  VALUES (p_ride_id, private.fn_ride_is_payment_protected(p_ride_id))
  ON CONFLICT (ride_id) DO UPDATE
    SET protected = public.ride_verification_state.protected
                    OR EXCLUDED.protected,
        updated_at = now()
  RETURNING * INTO v;
  IF NOT EXISTS (SELECT 1 FROM public.ride_pickup_versions WHERE ride_id = p_ride_id) THEN
    IF r.pickup_coords IS NOT NULL THEN
      v_lat := ST_Y(r.pickup_coords::geometry);
      v_lng := ST_X(r.pickup_coords::geometry);
      INSERT INTO public.ride_pickup_versions(
        ride_id, version, latitude, longitude, address, actor_type, change_reason
      ) VALUES (p_ride_id, 1, v_lat, v_lng, r.pickup_address, 'system', 'original_pickup')
      ON CONFLICT (ride_id, version) DO NOTHING;
    END IF;
  END IF;
  RETURN v;
END; $$;

CREATE OR REPLACE FUNCTION private.fn_claim_ride_command(
  p_ride_id uuid, p_command text, p_actor uuid, p_idempotency_key uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.ride_verification_commands(ride_id, command, actor_id, idempotency_key)
  VALUES (p_ride_id, p_command, p_actor, p_idempotency_key)
  ON CONFLICT DO NOTHING;
  RETURN FOUND;
END; $$;

CREATE OR REPLACE FUNCTION private.fn_generate_boarding_pin(p_ride_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_pin text; v_salt text := encode(extensions.gen_random_bytes(16), 'hex');
DECLARE v_cfg jsonb := private.fn_ride_verification_config();
DECLARE v_digits integer := COALESCE((v_cfg->>'boarding_pin_digits')::integer, 6);
DECLARE v_ttl integer := COALESCE((v_cfg->>'boarding_pin_ttl_minutes')::integer, 30);
BEGIN
  IF EXISTS (SELECT 1 FROM public.ride_boarding_secrets WHERE ride_id = p_ride_id) THEN RETURN; END IF;
  IF v_digits NOT IN (4,6) THEN RAISE EXCEPTION 'boarding_pin_config_invalid'; END IF;
  v_pin := CASE WHEN v_digits = 4
    THEN lpad((((('x'||encode(extensions.gen_random_bytes(4),'hex'))::bit(32)::bigint) % 9000) + 1000)::text, 4, '0')
    ELSE lpad((((('x'||encode(extensions.gen_random_bytes(4),'hex'))::bit(32)::bigint) % 900000) + 100000)::text, 6, '0') END;
  INSERT INTO public.ride_boarding_secrets(ride_id, pin_code) VALUES (p_ride_id, v_pin);
  UPDATE public.ride_verification_state SET
    boarding_pin_salt = v_salt,
    boarding_pin_hash = encode(extensions.digest(v_pin || v_salt, 'sha256'), 'hex'),
    boarding_pin_expires_at = now() + make_interval(mins => v_ttl),
    updated_at = now()
  WHERE ride_id = p_ride_id;
END; $$;

CREATE OR REPLACE FUNCTION public.request_driver_arrival(
  p_ride_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision,
  p_speed_kmh double precision,
  p_recorded_at timestamptz,
  p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid := private.fn_ride_driver_id(); r public.ride_requests%ROWTYPE;
DECLARE v public.ride_verification_state; c jsonb := private.fn_ride_verification_config();
DECLARE dist_m double precision; dwell integer; now_utc timestamptz := now();
DECLARE max_dist double precision := COALESCE((c->>'arrival_geofence_meters')::double precision,150);
DECLARE max_accuracy double precision := COALESCE((c->>'arrival_max_gps_accuracy_meters')::double precision,65);
DECLARE max_speed double precision := COALESCE((c->>'arrival_max_speed_kmh')::double precision,8);
DECLARE max_age integer := COALESCE((c->>'location_max_age_seconds')::integer,90);
DECLARE dwell_required integer := COALESCE((c->>'arrival_dwell_seconds')::integer,60);
BEGIN
  IF d IS NULL THEN RETURN jsonb_build_object('ok',false,'error','not_a_driver'); END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  IF r.driver_id IS DISTINCT FROM d OR r.status NOT IN ('accepted','driver_en_route','driver_arrived') THEN
    RETURN jsonb_build_object('ok',false,'error','invalid_transition','status',r.status);
  END IF;
  IF NOT private.fn_ride_verification_flag('ride_arrival_verification_enabled')
     OR NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN public.fn_driver_ride_arrived(p_ride_id)::jsonb;
  END IF;
  IF p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180
     OR p_accuracy_m IS NULL OR p_accuracy_m < 0 OR p_accuracy_m > max_accuracy
     OR p_speed_kmh IS NULL OR p_speed_kmh < 0 OR p_speed_kmh > max_speed
     OR p_recorded_at IS NULL OR p_recorded_at < now_utc-make_interval(secs=>max_age)
     OR p_recorded_at > now_utc+interval '10 seconds' THEN
    PERFORM public.fn_ride_audit_append(p_ride_id,'arrival.verification_rejected',d,
      jsonb_build_object('accuracy_m',p_accuracy_m,'speed_kmh',p_speed_kmh,'recorded_at',p_recorded_at),
      'driver','rpc',p_ride_id);
    RETURN jsonb_build_object('ok',false,'error','arrival_evidence_invalid');
  END IF;
  IF r.pickup_coords IS NULL THEN RETURN jsonb_build_object('ok',false,'error','pickup_coordinates_missing'); END IF;
  dist_m := ST_Distance(
    ST_SetSRID(ST_MakePoint(p_longitude,p_latitude),4326)::geography,
    r.pickup_coords
  );
  IF dist_m > max_dist THEN
    RETURN jsonb_build_object('ok',false,'error','outside_pickup_geofence','distance_m',round(dist_m),'max_m',max_dist);
  END IF;
  v := private.fn_ensure_ride_verification(p_ride_id);
  IF v.arrival_verified THEN
    RETURN jsonb_build_object('ok',true,'status','driver_arrived','verified',true,'idempotent_replay',true);
  END IF;
  UPDATE public.ride_verification_state SET
    arrival_requested_at=COALESCE(arrival_requested_at,now_utc),
    arrival_first_valid_sample_at=COALESCE(arrival_first_valid_sample_at,now_utc),
    arrival_lat=p_latitude, arrival_lng=p_longitude, arrival_accuracy_m=p_accuracy_m,
    updated_at=now_utc
  WHERE ride_id=p_ride_id RETURNING * INTO v;
  dwell := floor(extract(epoch FROM now_utc-v.arrival_first_valid_sample_at));
  IF dwell < dwell_required THEN
    PERFORM public.fn_ride_audit_append(p_ride_id,'arrival.verification_pending',d,
      jsonb_build_object('distance_m',round(dist_m),'dwell_seconds',dwell,'required_seconds',dwell_required),
      'driver','rpc',p_ride_id);
    RETURN jsonb_build_object('ok',true,'status','arrival_verification_pending','verified',false,
      'retry_after_seconds',dwell_required-dwell);
  END IF;
  UPDATE public.ride_verification_state SET arrival_verified=true,
    arrival_verified_at=now_utc, waiting_timer_started_at=now_utc,
    pickup_locked_at=COALESCE(pickup_locked_at,now_utc), updated_at=now_utc
  WHERE ride_id=p_ride_id;
  IF private.fn_ride_verification_flag('boarding_pin_enabled') THEN
    PERFORM private.fn_generate_boarding_pin(p_ride_id);
  END IF;
  UPDATE public.ride_requests SET status='driver_arrived',driver_arrived_at=now_utc,
    updated_at=now_utc WHERE id=p_ride_id AND status IN ('accepted','driver_en_route');
  PERFORM public.fn_driver_ride_lifecycle_audit(p_ride_id,'arrival.verified',d,
    jsonb_build_object('distance_m',round(dist_m),'accuracy_m',p_accuracy_m,'dwell_seconds',dwell));
  PERFORM public.fn_ride_notify_rider(p_ride_id,'driver_arrived','Your driver has arrived',
    'Your trip PIN is ready. Share it only after entering the vehicle.',
    jsonb_build_object('type','driver_arrived','arrival_verified',true),'high');
  RETURN jsonb_build_object('ok',true,'status','driver_arrived','verified',true);
END; $$;

CREATE OR REPLACE FUNCTION public.verify_boarding_pin(
  p_ride_id uuid, p_pin text, p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid := private.fn_ride_driver_id(); r public.ride_requests%ROWTYPE;
DECLARE v public.ride_verification_state; c jsonb := private.fn_ride_verification_config();
DECLARE max_attempts integer := COALESCE((c->>'boarding_pin_max_attempts')::integer,5);
BEGIN
  IF d IS NULL THEN RETURN jsonb_build_object('ok',false,'error','not_a_driver'); END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF r.id IS NULL OR r.driver_id IS DISTINCT FROM d THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id FOR UPDATE;
  IF v.ride_id IS NULL OR NOT v.arrival_verified OR r.status <> 'driver_arrived' THEN
    RETURN jsonb_build_object('ok',false,'error','arrival_not_verified');
  END IF;
  IF v.boarding_verified THEN RETURN jsonb_build_object('ok',true,'boarding_verified',true,'idempotent_replay',true); END IF;
  IF v.boarding_pin_expires_at IS NULL OR v.boarding_pin_expires_at < now() THEN
    RETURN jsonb_build_object('ok',false,'error','boarding_pin_expired');
  END IF;
  IF v.boarding_pin_failed_attempts >= max_attempts THEN RETURN jsonb_build_object('ok',false,'error','boarding_pin_locked'); END IF;
  IF encode(extensions.digest(btrim(COALESCE(p_pin,''))||v.boarding_pin_salt,'sha256'),'hex') <> v.boarding_pin_hash THEN
    UPDATE public.ride_verification_state SET boarding_pin_failed_attempts=boarding_pin_failed_attempts+1,updated_at=now() WHERE ride_id=p_ride_id;
    PERFORM public.fn_ride_audit_append(p_ride_id,'boarding.pin_rejected',d,
      jsonb_build_object('attempt',v.boarding_pin_failed_attempts+1,'max_attempts',max_attempts),'driver','rpc',p_ride_id);
    RETURN jsonb_build_object('ok',false,'error','boarding_pin_invalid','attempts_remaining',greatest(0,max_attempts-v.boarding_pin_failed_attempts-1));
  END IF;
  UPDATE public.ride_verification_state SET boarding_verified=true,boarding_verified_at=now(),
    boarding_verification_method='pin',boarding_pin_consumed_at=now(),updated_at=now() WHERE ride_id=p_ride_id;
  DELETE FROM public.ride_boarding_secrets WHERE ride_id=p_ride_id;
  PERFORM public.fn_ride_audit_append(p_ride_id,'boarding.pin_verified',d,'{}'::jsonb,'driver','rpc',p_ride_id);
  RETURN jsonb_build_object('ok',true,'boarding_verified',true,'method','pin');
END; $$;

CREATE OR REPLACE FUNCTION public.start_verified_ride(
  p_ride_id uuid, p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid := private.fn_ride_driver_id(); v public.ride_verification_state; result jsonb;
BEGIN
  IF NOT private.fn_ride_verification_flag('boarding_pin_enabled')
     OR NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN public.fn_driver_ride_start(p_ride_id)::jsonb;
  END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id FOR UPDATE;
  IF v.ride_id IS NULL OR NOT v.arrival_verified THEN RETURN jsonb_build_object('ok',false,'error','arrival_not_verified'); END IF;
  IF NOT v.boarding_verified THEN RETURN jsonb_build_object('ok',false,'error','boarding_verification_required'); END IF;
  result := public.fn_driver_ride_start(p_ride_id)::jsonb;
  IF COALESCE((result->>'ok')::boolean,false) THEN
    UPDATE public.ride_verification_state SET started_verified_at=now(),updated_at=now() WHERE ride_id=p_ride_id;
  END IF;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION public.complete_verified_ride(
  p_ride_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision,
  p_recorded_at timestamptz,
  p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid := private.fn_ride_driver_id(); r public.ride_requests%ROWTYPE;
DECLARE v public.ride_verification_state; c jsonb := private.fn_ride_verification_config();
DECLARE dest_dist double precision; route_m double precision := 0; duration_s integer := 0; max_jump_kmh double precision := 0;
DECLARE reasons jsonb := '[]'::jsonb; result jsonb; short_trip boolean;
DECLARE min_duration integer := COALESCE((c->>'completion_min_duration_seconds')::integer,120);
DECLARE min_distance double precision := COALESCE((c->>'completion_min_distance_meters')::double precision,100);
DECLARE dest_geofence double precision := COALESCE((c->>'destination_geofence_meters')::double precision,250);
DECLARE max_speed double precision := COALESCE((c->>'route_max_plausible_speed_kmh')::double precision,190);
BEGIN
  IF NOT private.fn_ride_verification_flag('verified_completion_enabled')
     OR NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN public.fn_driver_ride_complete(p_ride_id)::jsonb;
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF r.id IS NULL OR r.driver_id IS DISTINCT FROM d THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF r.status='completed' THEN RETURN jsonb_build_object('ok',true,'status','completed','idempotent_replay',true); END IF;
  IF r.status<>'in_progress' THEN RETURN jsonb_build_object('ok',false,'error','invalid_transition'); END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id FOR UPDATE;
  IF v.ride_id IS NULL OR NOT v.arrival_verified OR NOT v.boarding_verified OR v.started_verified_at IS NULL THEN
    RETURN jsonb_build_object('ok',false,'error','journey_evidence_incomplete');
  END IF;
  IF p_recorded_at < now()-interval '90 seconds' OR p_recorded_at > now()+interval '10 seconds'
     OR p_accuracy_m IS NULL OR p_accuracy_m > COALESCE((c->>'arrival_max_gps_accuracy_meters')::double precision,65) THEN
    reasons := reasons || '"destination_location_invalid"'::jsonb;
  END IF;
  IF r.destination_coords IS NULL THEN reasons := reasons || '"destination_coordinates_missing"'::jsonb;
  ELSE
    dest_dist := ST_Distance(ST_SetSRID(ST_MakePoint(p_longitude,p_latitude),4326)::geography,r.destination_coords);
    IF dest_dist > dest_geofence THEN reasons := reasons || jsonb_build_array('outside_destination_geofence'); END IF;
  END IF;
  duration_s := greatest(0,extract(epoch FROM (now()-r.started_at))::integer);
  short_trip := COALESCE(r.estimated_distance_km,999) < 0.5;
  WITH ordered AS (
    SELECT latitude,longitude,recorded_at,
      lag(latitude) OVER (ORDER BY recorded_at,id) p_lat,
      lag(longitude) OVER (ORDER BY recorded_at,id) p_lng,
      lag(recorded_at) OVER (ORDER BY recorded_at,id) p_at
    FROM public.ride_gps_track WHERE ride_request_id=p_ride_id
  ), legs AS (
    SELECT ST_Distance(ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326)::geography,
                       ST_SetSRID(ST_MakePoint(longitude,latitude),4326)::geography) meters,
           extract(epoch FROM (recorded_at-p_at)) seconds
    FROM ordered WHERE p_lat IS NOT NULL AND recorded_at>p_at
  ) SELECT COALESCE(sum(meters),0),COALESCE(max((meters/seconds)*3.6),0)
    INTO route_m,max_jump_kmh FROM legs;
  IF NOT short_trip AND duration_s < min_duration THEN reasons := reasons || jsonb_build_array('duration_too_short'); END IF;
  IF NOT short_trip AND route_m < min_distance THEN reasons := reasons || jsonb_build_array('distance_too_short'); END IF;
  IF max_jump_kmh > max_speed THEN reasons := reasons || jsonb_build_array('impossible_gps_jump'); END IF;
  IF EXISTS (SELECT 1 FROM public.ride_protection_cases pc WHERE pc.ride_id=p_ride_id AND pc.status IN ('open','reviewing') AND pc.case_type='safety_incident') THEN
    reasons := reasons || jsonb_build_array('open_safety_incident');
  END IF;
  UPDATE public.ride_verification_state SET destination_arrival_requested_at=now(),
    destination_arrival_lat=p_latitude,destination_arrival_lng=p_longitude,
    risk_reasons=reasons,
    risk_status=CASE WHEN jsonb_array_length(reasons)=0 THEN 'clear' ELSE 'review_required' END,
    completion_verified=(jsonb_array_length(reasons)=0),
    completion_verified_at=CASE WHEN jsonb_array_length(reasons)=0 THEN now() ELSE NULL END,
    destination_arrival_verified_at=CASE WHEN dest_dist IS NOT NULL AND dest_dist<=dest_geofence THEN now() ELSE NULL END,
    payment_eligible_at=CASE WHEN jsonb_array_length(reasons)=0 THEN now() ELSE NULL END,
    updated_at=now() WHERE ride_id=p_ride_id;
  IF jsonb_array_length(reasons)>0 THEN
    INSERT INTO public.ride_protection_cases(ride_id,case_type,opened_by_type,opened_by,reason)
    VALUES(p_ride_id,'completion_review','system',d,'Automatic completion evidence review: '||reasons::text);
    PERFORM public.fn_ride_audit_append(p_ride_id,'completion.review_required',d,
      jsonb_build_object('reasons',reasons,'route_m',round(route_m),'duration_s',duration_s,'destination_distance_m',round(dest_dist)),
      'system','verification',p_ride_id);
    RETURN jsonb_build_object('ok',true,'status','review_required','payment_status','paid_unrouted','reasons',reasons);
  END IF;
  PERFORM public.fn_ride_audit_append(p_ride_id,'completion.verified',d,
    jsonb_build_object('route_m',round(route_m),'duration_s',duration_s,'destination_distance_m',round(dest_dist)),
    'system','verification',p_ride_id);
  result := public.fn_driver_ride_complete(p_ride_id)::jsonb;
  RETURN result || jsonb_build_object('completion_verified',true,'payment_eligible',true);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_ride_payment_evidence_gate(p_ride_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.ride_verification_state; r public.ride_requests%ROWTYPE;
BEGIN
  IF NOT private.fn_ride_verification_flag('payment_evidence_gate_enabled')
     OR NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN jsonb_build_object('allowed',true,'required',false,'reason','flag_disabled_or_not_prepaid');
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id;
  IF r.status='completed' AND v.arrival_verified AND v.boarding_verified
     AND v.started_verified_at IS NOT NULL AND v.completion_verified
     AND v.risk_status='clear' AND v.payment_eligible_at IS NOT NULL THEN
    RETURN jsonb_build_object('allowed',true,'required',true,'reason','verified_service');
  END IF;
  RETURN jsonb_build_object('allowed',false,'required',true,'reason','ride_evidence_incomplete',
    'ride_status',r.status,'arrival_verified',COALESCE(v.arrival_verified,false),
    'boarding_verified',COALESCE(v.boarding_verified,false),'completion_verified',COALESCE(v.completion_verified,false),
    'risk_status',COALESCE(v.risk_status,'missing'));
END; $$;

CREATE OR REPLACE FUNCTION public.fn_ride_verification_snapshot(
  p_ride_id uuid, p_rider_token text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; v public.ride_verification_state; actor text; pin text;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  IF private.fn_ride_rider_authorized(r,p_rider_token) THEN actor:='rider';
  ELSIF EXISTS(SELECT 1 FROM public.drivers d WHERE d.id=r.driver_id AND d.user_id=auth.uid()) THEN actor:='driver';
  ELSIF EXISTS(SELECT 1 FROM public.admin_users a WHERE a.user_id=auth.uid() AND a.is_active) THEN actor:='admin';
  ELSE RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id;
  IF actor='rider' AND v.boarding_pin_consumed_at IS NULL AND v.boarding_pin_expires_at>now() THEN
    SELECT pin_code INTO pin FROM public.ride_boarding_secrets WHERE ride_id=p_ride_id;
  END IF;
  RETURN jsonb_build_object('ok',true,'actor',actor,'protected',COALESCE(v.protected,false),
    'pickup_version',COALESCE(v.pickup_version,1),'pickup_locked_at',v.pickup_locked_at,
    'arrival_verified',COALESCE(v.arrival_verified,false),'arrival_verified_at',v.arrival_verified_at,
    'waiting_timer_started_at',v.waiting_timer_started_at,'boarding_pin',pin,
    'boarding_pin_expires_at',v.boarding_pin_expires_at,'boarding_pin_attempts',COALESCE(v.boarding_pin_failed_attempts,0),
    'boarding_verified',COALESCE(v.boarding_verified,false),'boarding_method',v.boarding_verification_method,
    'completion_verified',COALESCE(v.completion_verified,false),'risk_status',COALESCE(v.risk_status,'clear'),
    'risk_reasons',COALESCE(v.risk_reasons,'[]'::jsonb),'payment_eligible_at',v.payment_eligible_at);
END; $$;

CREATE OR REPLACE FUNCTION public.record_ride_contact_attempt(
  p_ride_id uuid, p_channel text, p_outcome text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; d uuid := private.fn_ride_driver_id(); actor text;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id;
  IF d IS NOT NULL AND r.driver_id=d THEN actor:='driver';
  ELSIF private.fn_ride_rider_authorized(r,NULL) THEN actor:='rider';
  ELSE RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF p_channel NOT IN ('chat','masked_call') THEN RETURN jsonb_build_object('ok',false,'error','invalid_channel'); END IF;
  INSERT INTO public.ride_contact_attempts(ride_id,actor_type,actor_id,channel,outcome)
  VALUES(p_ride_id,actor,auth.uid(),p_channel,NULLIF(btrim(p_outcome),''));
  PERFORM public.fn_ride_audit_append(p_ride_id,'contact.attempted',auth.uid(),jsonb_build_object('channel',p_channel,'outcome',p_outcome),actor,'rpc',p_ride_id);
  RETURN jsonb_build_object('ok',true);
END; $$;

CREATE OR REPLACE FUNCTION public.request_pickup_change(
  p_ride_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_rider_token text DEFAULT NULL,
  p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; v public.ride_verification_state;
DECLARE c jsonb := private.fn_ride_verification_config(); d uuid;
DECLARE old_lat double precision; old_lng double precision; delta_m double precision;
DECLARE driver_dist_m double precision; max_delta double precision := COALESCE((c->>'maximum_pickup_change_distance_meters')::double precision,2000);
DECLARE lock_dist double precision := COALESCE((c->>'pickup_edit_lock_distance_meters')::double precision,500);
DECLARE max_changes integer := COALESCE((c->>'maximum_pickup_changes')::integer,3); request_id uuid;
BEGIN
  IF p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180
     OR NULLIF(btrim(COALESCE(p_address,'')),'') IS NULL THEN
    RETURN jsonb_build_object('ok',false,'error','invalid_pickup');
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  IF NOT private.fn_ride_rider_authorized(r,p_rider_token) THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF r.status NOT IN ('pending','bidding','accepted','assigned','driver_found','driver_en_route','driver_arrived') THEN
    RETURN jsonb_build_object('ok',false,'error','pickup_not_editable','status',r.status);
  END IF;
  v := private.fn_ensure_ride_verification(p_ride_id);
  old_lat := ST_Y(r.pickup_coords::geometry); old_lng := ST_X(r.pickup_coords::geometry);
  delta_m := ST_Distance(r.pickup_coords,ST_SetSRID(ST_MakePoint(p_longitude,p_latitude),4326)::geography);
  IF delta_m > max_delta THEN RETURN jsonb_build_object('ok',false,'error','pickup_change_too_large','distance_m',round(delta_m),'max_m',max_delta,'requires_new_booking',true); END IF;
  IF (SELECT count(*) FROM public.ride_pickup_versions x WHERE x.ride_id=p_ride_id)>max_changes THEN
    RETURN jsonb_build_object('ok',false,'error','maximum_pickup_changes_reached');
  END IF;
  IF r.driver_id IS NOT NULL THEN
    SELECT ST_Distance(ST_SetSRID(ST_MakePoint(dl.longitude,dl.latitude),4326)::geography,r.pickup_coords)
      INTO driver_dist_m FROM public.driver_locations dl
      WHERE dl.driver_id=r.driver_id AND dl.updated_at>now()-interval '3 minutes' LIMIT 1;
  END IF;
  IF private.fn_ride_verification_flag('pickup_locking_enabled')
     AND (v.pickup_locked_at IS NOT NULL OR r.status='driver_arrived' OR COALESCE(driver_dist_m,1e12)<=lock_dist) THEN
    UPDATE public.ride_verification_state SET pickup_locked_at=COALESCE(pickup_locked_at,now()),updated_at=now() WHERE ride_id=p_ride_id;
    INSERT INTO public.ride_pickup_change_requests(ride_id,from_version,requested_lat,requested_lng,requested_address,distance_delta_m,requested_by)
    VALUES(p_ride_id,v.pickup_version,p_latitude,p_longitude,btrim(p_address),round(delta_m),auth.uid())
    ON CONFLICT (ride_id) WHERE status='pending' DO UPDATE SET
      requested_lat=EXCLUDED.requested_lat,requested_lng=EXCLUDED.requested_lng,
      requested_address=EXCLUDED.requested_address,distance_delta_m=EXCLUDED.distance_delta_m,
      requested_by=EXCLUDED.requested_by,requested_at=now()
    RETURNING id INTO request_id;
    PERFORM public.fn_ride_audit_append(p_ride_id,'pickup.change_requested',auth.uid(),
      jsonb_build_object('request_id',request_id,'from_version',v.pickup_version,'distance_delta_m',round(delta_m)),
      'rider','rpc',p_ride_id);
    RETURN jsonb_build_object('ok',true,'status','driver_approval_required','request_id',request_id,'distance_delta_m',round(delta_m));
  END IF;
  UPDATE public.ride_requests SET pickup_address=btrim(p_address),
    pickup_coords=ST_SetSRID(ST_MakePoint(p_longitude,p_latitude),4326)::geography,
    pickup_lat=p_latitude,pickup_lng=p_longitude,updated_at=now() WHERE id=p_ride_id;
  UPDATE public.ride_verification_state SET pickup_version=pickup_version+1,updated_at=now()
    WHERE ride_id=p_ride_id RETURNING * INTO v;
  INSERT INTO public.ride_pickup_versions(ride_id,version,latitude,longitude,address,actor_type,actor_id,change_reason)
  VALUES(p_ride_id,v.pickup_version,p_latitude,p_longitude,btrim(p_address),'rider',auth.uid(),'rider_change_before_lock');
  PERFORM public.fn_ride_audit_append(p_ride_id,'pickup.changed',auth.uid(),
    jsonb_build_object('version',v.pickup_version,'distance_delta_m',round(delta_m),'previous_lat',old_lat,'previous_lng',old_lng),
    'rider','rpc',p_ride_id);
  RETURN jsonb_build_object('ok',true,'status','updated','pickup_version',v.pickup_version,'distance_delta_m',round(delta_m));
END; $$;

CREATE OR REPLACE FUNCTION public.respond_to_pickup_change(
  p_request_id uuid, p_accept boolean, p_reason text DEFAULT NULL,
  p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid := private.fn_ride_driver_id(); q public.ride_pickup_change_requests%ROWTYPE;
DECLARE r public.ride_requests%ROWTYPE; v public.ride_verification_state;
BEGIN
  SELECT * INTO q FROM public.ride_pickup_change_requests WHERE id=p_request_id FOR UPDATE;
  IF q.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','pickup_change_not_found'); END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=q.ride_id FOR UPDATE;
  IF d IS NULL OR r.driver_id IS DISTINCT FROM d THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF q.status<>'pending' THEN RETURN jsonb_build_object('ok',true,'status',q.status,'idempotent_replay',true); END IF;
  IF NOT p_accept THEN
    UPDATE public.ride_pickup_change_requests SET status='rejected',responded_by=d,responded_at=now(),response_reason=NULLIF(btrim(p_reason),'') WHERE id=q.id;
    PERFORM public.fn_ride_audit_append(q.ride_id,'pickup.change_rejected',d,jsonb_build_object('request_id',q.id,'reason',p_reason),'driver','rpc',q.ride_id);
    RETURN jsonb_build_object('ok',true,'status','rejected');
  END IF;
  UPDATE public.ride_requests SET pickup_address=q.requested_address,
    pickup_coords=ST_SetSRID(ST_MakePoint(q.requested_lng,q.requested_lat),4326)::geography,
    pickup_lat=q.requested_lat,pickup_lng=q.requested_lng,updated_at=now() WHERE id=q.ride_id;
  UPDATE public.ride_verification_state SET pickup_version=pickup_version+1,updated_at=now()
    WHERE ride_id=q.ride_id RETURNING * INTO v;
  INSERT INTO public.ride_pickup_versions(ride_id,version,latitude,longitude,address,actor_type,actor_id,change_reason)
  VALUES(q.ride_id,v.pickup_version,q.requested_lat,q.requested_lng,q.requested_address,'driver',d,'driver_accepted_late_change');
  UPDATE public.ride_pickup_change_requests SET status='accepted',responded_by=d,responded_at=now(),response_reason=NULLIF(btrim(p_reason),'') WHERE id=q.id;
  PERFORM public.fn_ride_audit_append(q.ride_id,'pickup.change_accepted',d,jsonb_build_object('request_id',q.id,'pickup_version',v.pickup_version),'driver','rpc',q.ride_id);
  RETURN jsonb_build_object('ok',true,'status','accepted','pickup_version',v.pickup_version);
END; $$;

CREATE OR REPLACE FUNCTION public.request_driver_no_show(
  p_ride_id uuid, p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid := private.fn_ride_driver_id(); r public.ride_requests%ROWTYPE;
DECLARE v public.ride_verification_state; c jsonb:=private.fn_ride_verification_config();
DECLARE wait_required integer:=COALESCE((c->>'no_show_wait_seconds')::integer,300);
DECLARE waited integer; dist_m double precision;
BEGIN
  IF NOT private.fn_ride_verification_flag('ride_arrival_verification_enabled')
     OR NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN public.fn_driver_ride_no_show(p_ride_id)::jsonb;
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id FOR UPDATE;
  IF d IS NULL OR r.driver_id IS DISTINCT FROM d THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF r.status<>'driver_arrived' OR NOT COALESCE(v.arrival_verified,false) OR v.boarding_verified THEN
    RETURN jsonb_build_object('ok',false,'error','no_show_not_eligible');
  END IF;
  waited:=greatest(0,extract(epoch FROM (now()-v.waiting_timer_started_at))::integer);
  IF waited<wait_required THEN RETURN jsonb_build_object('ok',false,'error','waiting_period_not_complete','remaining_seconds',wait_required-waited); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.ride_contact_attempts x WHERE x.ride_id=p_ride_id AND x.actor_type='driver' AND x.channel IN ('chat','masked_call')) THEN
    RETURN jsonb_build_object('ok',false,'error','contact_attempt_required');
  END IF;
  SELECT ST_Distance(ST_SetSRID(ST_MakePoint(dl.longitude,dl.latitude),4326)::geography,r.pickup_coords)
    INTO dist_m FROM public.driver_locations dl WHERE dl.driver_id=d AND dl.updated_at>now()-interval '90 seconds' LIMIT 1;
  IF dist_m IS NULL OR dist_m>COALESCE((c->>'arrival_geofence_meters')::double precision,150) THEN
    RETURN jsonb_build_object('ok',false,'error','driver_left_pickup_area','distance_m',round(dist_m));
  END IF;
  PERFORM public.fn_ride_audit_append(p_ride_id,'no_show.verified',d,
    jsonb_build_object('waited_seconds',waited,'distance_m',round(dist_m),'contact_attempts',(SELECT count(*) FROM public.ride_contact_attempts x WHERE x.ride_id=p_ride_id)),
    'system','verification',p_ride_id);
  RETURN public.fn_driver_ride_no_show(p_ride_id)::jsonb;
END; $$;

CREATE OR REPLACE FUNCTION public.request_rider_cancellation(
  p_ride_id uuid, p_rider_token text DEFAULT NULL, p_reason text DEFAULT NULL,
  p_idempotency_key uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; v public.ride_verification_state; case_id uuid;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id FOR UPDATE;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  IF NOT private.fn_ride_rider_authorized(r,p_rider_token) THEN RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF NOT private.fn_ride_is_payment_protected(p_ride_id) THEN
    RETURN public.fn_rider_cancel_open_ride(p_ride_id,p_rider_token,p_reason)::jsonb;
  END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id;
  IF r.status='in_progress' OR COALESCE(v.boarding_verified,false) THEN
    INSERT INTO public.ride_protection_cases(ride_id,case_type,opened_by_type,opened_by,reason)
    VALUES(p_ride_id,'end_trip_early','rider',auth.uid(),COALESCE(NULLIF(btrim(p_reason),''),'Rider requested an early trip end')) RETURNING id INTO case_id;
    PERFORM public.fn_ride_audit_append(p_ride_id,'cancellation.converted_to_case',auth.uid(),jsonb_build_object('case_id',case_id,'status',r.status),'rider','rpc',p_ride_id);
    RETURN jsonb_build_object('ok',true,'status','support_review','case_id',case_id,'normal_cancellation_disabled',true);
  END IF;
  RETURN public.fn_rider_cancel_open_ride(p_ride_id,p_rider_token,p_reason)::jsonb;
END; $$;

-- Privacy-conscious route evidence hardening. Legacy rides retain the existing
-- behavior; protected rides reject stale, replayed, inaccurate, or oversized
-- client batches and always bind samples to the authenticated assigned driver.
CREATE OR REPLACE FUNCTION public.fn_insert_ride_gps_batch(p_ride_request_id uuid,p_points jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE d uuid:=private.fn_ride_driver_id(); r public.ride_requests%ROWTYPE; p jsonb;
DECLARE ts timestamptz; lat double precision; lng double precision; accuracy double precision;
DECLARE protected boolean;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_request_id;
  IF d IS NULL OR r.driver_id IS DISTINCT FROM d OR r.status<>'in_progress' THEN RETURN; END IF;
  IF jsonb_typeof(p_points)<>'array' THEN RETURN; END IF;
  protected:=private.fn_ride_verification_flag('route_evidence_enabled') AND private.fn_ride_is_payment_protected(p_ride_request_id);
  IF protected AND jsonb_array_length(p_points)>100 THEN RAISE EXCEPTION 'route_batch_too_large'; END IF;
  FOR p IN SELECT value FROM jsonb_array_elements(p_points) LOOP
    BEGIN
      lat:=(p->>'lat')::double precision; lng:=(p->>'lng')::double precision;
      accuracy:=NULLIF(p->>'accuracy','')::double precision; ts:=(p->>'recorded_at')::timestamptz;
    EXCEPTION WHEN OTHERS THEN IF protected THEN RAISE EXCEPTION 'route_sample_invalid'; ELSE CONTINUE; END IF; END;
    IF lat NOT BETWEEN -90 AND 90 OR lng NOT BETWEEN -180 AND 180 THEN IF protected THEN RAISE EXCEPTION 'route_sample_invalid'; ELSE CONTINUE; END IF; END IF;
    IF protected AND (ts<greatest(r.started_at,now()-interval '5 minutes') OR ts>now()+interval '10 seconds' OR accuracy IS NULL OR accuracy>100) THEN
      RAISE EXCEPTION 'route_sample_untrusted';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM public.ride_gps_track x WHERE x.ride_request_id=p_ride_request_id AND x.driver_id=d AND x.recorded_at=ts) THEN
      INSERT INTO public.ride_gps_track(ride_request_id,driver_id,latitude,longitude,heading,speed_mps,accuracy_m,recorded_at)
      VALUES(p_ride_request_id,d,lat,lng,NULLIF(p->>'heading','')::double precision,NULLIF(p->>'speed','')::double precision,accuracy,ts);
    END IF;
  END LOOP;
END; $$;

CREATE OR REPLACE FUNCTION public.open_ride_dispute(
  p_ride_id uuid, p_case_type text, p_reason text, p_rider_token text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; actor text; case_id uuid;
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id;
  IF private.fn_ride_rider_authorized(r,p_rider_token) THEN actor:='rider';
  ELSIF EXISTS(SELECT 1 FROM public.drivers d WHERE d.id=r.driver_id AND d.user_id=auth.uid()) THEN actor:='driver';
  ELSE RETURN jsonb_build_object('ok',false,'error','not_authorized'); END IF;
  IF p_case_type NOT IN ('end_trip_early','report_driver','safety_incident','payment_dispute','refund_request')
     OR char_length(btrim(COALESCE(p_reason,'')))<3 THEN RETURN jsonb_build_object('ok',false,'error','invalid_case'); END IF;
  INSERT INTO public.ride_protection_cases(ride_id,case_type,opened_by_type,opened_by,reason)
  VALUES(p_ride_id,p_case_type,actor,auth.uid(),btrim(p_reason)) RETURNING id INTO case_id;
  PERFORM public.fn_ride_audit_append(p_ride_id,'dispute.opened',auth.uid(),jsonb_build_object('case_id',case_id,'case_type',p_case_type),actor,'rpc',p_ride_id);
  RETURN jsonb_build_object('ok',true,'case_id',case_id,'status','open');
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_ride_evidence_timeline(p_ride_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE a public.admin_users; r public.ride_requests%ROWTYPE; v public.ride_verification_state;
BEGIN
  a := private.fn_admin_os_actor('rides.read');
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','ride_not_found'); END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=p_ride_id;
  RETURN jsonb_build_object('ok',true,'ride',jsonb_build_object('id',r.id,'status',r.status,'booking_mode',r.booking_mode,
      'created_at',r.created_at,'accepted_at',r.accepted_at,'driver_arrived_at',r.driver_arrived_at,'started_at',r.started_at,'completed_at',r.completed_at),
    'verification',to_jsonb(v)-'boarding_pin_hash'-'boarding_pin_salt',
    'pickup_versions',(SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.version),'[]'::jsonb) FROM public.ride_pickup_versions x WHERE x.ride_id=p_ride_id),
    'contacts',(SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.occurred_at),'[]'::jsonb) FROM public.ride_contact_attempts x WHERE x.ride_id=p_ride_id),
    'cases',(SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.created_at),'[]'::jsonb) FROM public.ride_protection_cases x WHERE x.ride_id=p_ride_id),
    'events',(SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.occurred_at),'[]'::jsonb) FROM public.ride_audit_log x WHERE x.ride_id=p_ride_id),
    'payment',(SELECT to_jsonb(x)-'provider_snapshot' FROM public.ride_payments x WHERE x.ride_id=p_ride_id ORDER BY x.created_at DESC LIMIT 1),
    'route_summary',(SELECT jsonb_build_object('samples',count(*),'first_at',min(recorded_at),'last_at',max(recorded_at)) FROM public.ride_gps_track x WHERE x.ride_request_id=p_ride_id));
END; $$;

-- Independent enforcement: no legacy RPC, direct table write, or modified app
-- may bypass verified boarding/completion once the corresponding flag is on.
CREATE OR REPLACE FUNCTION private.trg_enforce_protected_ride_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.ride_verification_state; protected boolean;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  protected := private.fn_ride_is_payment_protected(NEW.id);
  IF NOT protected THEN RETURN NEW; END IF;
  SELECT * INTO v FROM public.ride_verification_state WHERE ride_id=NEW.id;
  IF NEW.status='driver_arrived' AND private.fn_ride_verification_flag('ride_arrival_verification_enabled')
     AND NOT COALESCE(v.arrival_verified,false) THEN RAISE EXCEPTION 'arrival_verification_required' USING ERRCODE='P0001'; END IF;
  IF NEW.status='in_progress' AND private.fn_ride_verification_flag('boarding_pin_enabled')
     AND (NOT COALESCE(v.arrival_verified,false) OR NOT COALESCE(v.boarding_verified,false)) THEN
    RAISE EXCEPTION 'boarding_verification_required' USING ERRCODE='P0001';
  END IF;
  IF NEW.status='completed' AND private.fn_ride_verification_flag('verified_completion_enabled')
     AND (NOT COALESCE(v.completion_verified,false) OR COALESCE(v.risk_status,'blocked')<>'clear') THEN
    RAISE EXCEPTION 'completion_verification_required' USING ERRCODE='P0001';
  END IF;
  IF NEW.status='cancelled' AND OLD.status='in_progress'
     AND private.fn_ride_verification_flag('boarding_pin_enabled') THEN
    RAISE EXCEPTION 'active_ride_requires_case_review' USING ERRCODE='P0001';
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_enforce_protected_ride_transition ON public.ride_requests;
CREATE TRIGGER trg_enforce_protected_ride_transition
BEFORE UPDATE OF status ON public.ride_requests
FOR EACH ROW EXECUTE FUNCTION private.trg_enforce_protected_ride_transition();

REVOKE ALL ON FUNCTION private.fn_ride_verification_config() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_ride_verification_flag(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_ride_is_payment_protected(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_ride_rider_authorized(public.ride_requests,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_ride_driver_id() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_ensure_ride_verification(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_claim_ride_command(uuid,text,uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.fn_generate_boarding_pin(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.trg_enforce_protected_ride_transition() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.trg_reject_ride_evidence_mutation() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION public.request_driver_arrival(uuid,double precision,double precision,double precision,double precision,timestamptz,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_driver_arrival(uuid,double precision,double precision,double precision,double precision,timestamptz,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.verify_boarding_pin(uuid,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.verify_boarding_pin(uuid,text,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.start_verified_ride(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.start_verified_ride(uuid,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.complete_verified_ride(uuid,double precision,double precision,double precision,timestamptz,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_verified_ride(uuid,double precision,double precision,double precision,timestamptz,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.fn_ride_payment_evidence_gate(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_payment_evidence_gate(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.fn_ride_verification_snapshot(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ride_verification_snapshot(uuid,text) TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.record_ride_contact_attempt(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_ride_contact_attempt(uuid,text,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.request_pickup_change(uuid,double precision,double precision,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_pickup_change(uuid,double precision,double precision,text,text,uuid) TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.respond_to_pickup_change(uuid,boolean,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.respond_to_pickup_change(uuid,boolean,text,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.request_driver_no_show(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_driver_no_show(uuid,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.request_rider_cancellation(uuid,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_rider_cancellation(uuid,text,text,uuid) TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.fn_insert_ride_gps_batch(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_insert_ride_gps_batch(uuid,jsonb) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.open_ride_dispute(uuid,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.open_ride_dispute(uuid,text,text,text) TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.fn_admin_ride_evidence_timeline(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_ride_evidence_timeline(uuid) TO authenticated,service_role;

COMMENT ON TABLE public.ride_verification_state IS 'Backend-owned verification projection for protected prepaid rides.';
COMMENT ON TABLE public.ride_pickup_versions IS 'Append-only official pickup location history.';
COMMENT ON FUNCTION public.fn_ride_payment_evidence_gate(uuid) IS 'Authoritative settlement gate consumed by Mollie routing; app roles cannot execute it.';
