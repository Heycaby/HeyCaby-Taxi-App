-- HeyCaby masked voice control plane.
-- Business policy remains in Postgres; Twilio is transport only.

INSERT INTO public.app_config(key, value)
VALUES (
  'ride_communication_config',
  '{"masked_calling_enabled":false,"call_start_status":"driver_arrived","max_call_seconds":300,"post_ride_call_minutes":10,"post_ride_message_minutes":120,"max_call_attempts_per_side":3,"minimum_seconds_between_attempts":30,"number_cooldown_minutes":45,"record_calls":false,"today_rides_hours":24}'
)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.twilio_number_pool (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  twilio_number_sid text NOT NULL UNIQUE CHECK (twilio_number_sid ~ '^PN[0-9a-fA-F]{32}$'),
  e164_number text NOT NULL UNIQUE CHECK (e164_number ~ '^\+[1-9][0-9]{7,14}$'),
  country text NOT NULL DEFAULT 'NL' CHECK (country ~ '^[A-Z]{2}$'),
  capabilities jsonb NOT NULL DEFAULT '{"voice":true}'::jsonb,
  environment text NOT NULL CHECK (environment IN ('production','development')),
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','reserved','active','cooldown','disabled','failed')),
  active_session_count integer NOT NULL DEFAULT 0 CHECK (active_session_count >= 0),
  reserved_until timestamptz,
  last_used_at timestamptz,
  health_state text NOT NULL DEFAULT 'unknown' CHECK (health_state IN ('unknown','healthy','degraded','failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  disabled_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.ride_communication_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid NOT NULL UNIQUE REFERENCES public.ride_requests(id) ON DELETE RESTRICT,
  rider_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  driver_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  number_pool_id uuid REFERENCES public.twilio_number_pool(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','call_expired','message_only','closed','suspended')),
  call_enabled_at timestamptz,
  ride_completed_at timestamptz,
  call_expires_at timestamptz,
  message_expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  close_reason text
);

CREATE TABLE IF NOT EXISTS public.ride_call_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  communication_session_id uuid NOT NULL REFERENCES public.ride_communication_sessions(id) ON DELETE RESTRICT,
  ride_request_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE RESTRICT,
  initiator_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  initiator_role text NOT NULL CHECK (initiator_role IN ('rider','driver','admin')),
  recipient_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  client_idempotency_key uuid NOT NULL,
  twilio_call_sid text UNIQUE,
  twilio_parent_call_sid text,
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','queued','initiated','ringing','in_progress','completed','busy','no_answer','failed','canceled')),
  started_at timestamptz,
  answered_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer CHECK (duration_seconds BETWEEN 0 AND 300),
  price numeric(12,6),
  price_unit text,
  failure_code text,
  failure_message text,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_request_id, initiator_user_id, client_idempotency_key)
);

CREATE UNIQUE INDEX IF NOT EXISTS ride_call_attempts_one_active_per_ride
  ON public.ride_call_attempts(ride_request_id)
  WHERE status IN ('requested','queued','initiated','ringing','in_progress');
CREATE INDEX IF NOT EXISTS ride_call_attempts_session_created_idx
  ON public.ride_call_attempts(communication_session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS twilio_number_pool_allocator_idx
  ON public.twilio_number_pool(environment, status, last_used_at)
  WHERE status = 'available';

CREATE TABLE IF NOT EXISTS public.twilio_voice_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_key text NOT NULL UNIQUE,
  twilio_call_sid text,
  event_type text NOT NULL,
  payload_redacted jsonb NOT NULL DEFAULT '{}'::jsonb,
  signature_valid boolean NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processing_error text
);

CREATE TABLE IF NOT EXISTS public.twilio_usage_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  balance_amount numeric(14,6),
  balance_currency text,
  calls_today integer NOT NULL DEFAULT 0,
  connected_seconds_today bigint NOT NULL DEFAULT 0,
  voice_cost_today numeric(14,6),
  number_cost_month numeric(14,6),
  captured_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.twilio_number_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_communication_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_call_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.twilio_voice_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.twilio_usage_snapshots ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.twilio_number_pool, public.ride_communication_sessions,
  public.ride_call_attempts, public.twilio_voice_webhook_events,
  public.twilio_usage_snapshots FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.twilio_number_pool, public.ride_communication_sessions,
  public.ride_call_attempts, public.twilio_voice_webhook_events,
  public.twilio_usage_snapshots TO service_role;

CREATE OR REPLACE FUNCTION private.fn_ride_communication_config()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v jsonb;
BEGIN
  SELECT value::jsonb INTO v FROM public.app_config WHERE key='ride_communication_config';
  RETURN COALESCE(v, '{}'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'ride_communication_config_invalid' USING ERRCODE='22023';
END; $$;
REVOKE ALL ON FUNCTION private.fn_ride_communication_config() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_ride_communication_permissions(p_ride_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  c jsonb := private.fn_ride_communication_config();
  r public.ride_requests%ROWTYPE;
  d public.drivers%ROWTYPE;
  uid uuid := auth.uid();
  actor_role text;
  rider_user uuid;
  driver_user uuid;
  call_until timestamptz;
  message_until timestamptz;
  can_call boolean := false;
  can_message boolean := false;
  reason text;
  blocked boolean := false;
  phone_ready boolean := false;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object('allowed',false,'can_call',false,'can_message',false,'reason','unauthorized');
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed',false,'can_call',false,'can_message',false,'reason','ride_not_assigned');
  END IF;
  SELECT * INTO d FROM public.drivers WHERE id=r.driver_id;
  driver_user := d.user_id;
  rider_user := COALESCE(r.rider_id, (SELECT ri.user_id FROM public.rider_identities ri WHERE ri.id=r.rider_identity_id));
  IF uid=driver_user THEN actor_role:='driver';
  ELSIF uid=rider_user THEN actor_role:='rider';
  ELSE
    RETURN jsonb_build_object('allowed',false,'can_call',false,'can_message',false,'reason','not_a_participant');
  END IF;
  IF r.driver_id IS NULL OR driver_user IS NULL THEN reason:='ride_not_assigned';
  ELSIF r.status IN ('cancelled','canceled','expired') THEN reason:='ride_cancelled';
  ELSIF COALESCE(d.account_status,'active') NOT IN ('active','approved')
     OR COALESCE(d.compliance_status,'clear') IN ('suspended','blocked','rejected') THEN reason:='account_deactivated';
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.ride_chat_blocks b WHERE b.ride_id=r.id
      AND ((b.blocker_id=uid::text) OR (b.blocked_id=uid::text))
  ) INTO blocked;
  IF blocked THEN reason:='participant_blocked'; END IF;

  IF r.completed_at IS NOT NULL THEN
    call_until := r.completed_at + make_interval(mins=>COALESCE((c->>'post_ride_call_minutes')::int,10));
    message_until := r.completed_at + make_interval(mins=>COALESCE((c->>'post_ride_message_minutes')::int,120));
  END IF;
  can_message := reason IS NULL AND (
    r.status IN ('accepted','assigned','driver_found','driver_en_route','arrived','driver_arrived','in_progress')
    OR (r.status='completed' AND now()<message_until)
  );
  can_call := reason IS NULL
    AND COALESCE((c->>'masked_calling_enabled')::boolean,false)
    AND (r.status IN ('driver_arrived','in_progress') OR (r.status='completed' AND now()<call_until));
  IF reason IS NULL AND NOT COALESCE((c->>'masked_calling_enabled')::boolean,false) THEN reason:='twilio_unavailable';
  ELSIF reason IS NULL AND NOT can_call AND r.status NOT IN ('completed') THEN reason:='driver_not_arrived';
  ELSIF reason IS NULL AND r.status='completed' AND now()>=call_until THEN reason:='call_window_expired';
  END IF;

  SELECT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=uid AND NULLIF(btrim(u.phone),'') IS NOT NULL AND u.phone_confirmed_at IS NOT NULL)
    OR (actor_role='driver' AND NULLIF(btrim(d.phone),'') IS NOT NULL)
  INTO phone_ready;
  IF can_call AND NOT phone_ready THEN can_call:=false; reason:='phone_missing'; END IF;

  RETURN jsonb_build_object(
    'allowed',reason IS NULL OR can_message,'participant_role',actor_role,'ride_status',r.status,
    'can_call',can_call,'can_message',can_message,'call_available_until',call_until,
    'message_available_until',message_until,'max_call_seconds',COALESCE((c->>'max_call_seconds')::int,300),
    'today_rides_until',COALESCE(r.completed_at,r.updated_at)+make_interval(hours=>COALESCE((c->>'today_rides_hours')::int,24)),
    'reason',CASE WHEN can_call THEN NULL ELSE reason END
  );
END; $$;

REVOKE ALL ON FUNCTION public.fn_ride_communication_permissions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_ride_communication_permissions(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_create_masked_call_intent(
  p_ride_request_id uuid, p_idempotency_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  permission jsonb;
  c jsonb := private.fn_ride_communication_config();
  r public.ride_requests%ROWTYPE;
  d public.drivers%ROWTYPE;
  actor_role text;
  rider_user uuid;
  recipient uuid;
  s public.ride_communication_sessions%ROWTYPE;
  n public.twilio_number_pool%ROWTYPE;
  a public.ride_call_attempts%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR p_idempotency_key IS NULL THEN
    RETURN jsonb_build_object('ok',false,'code','unauthorized');
  END IF;
  permission:=public.fn_ride_communication_permissions(p_ride_request_id);
  IF NOT COALESCE((permission->>'can_call')::boolean,false) THEN
    RETURN jsonb_build_object('ok',false,'code',COALESCE(permission->>'reason','calling_unavailable'));
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_request_id FOR UPDATE;
  SELECT * INTO d FROM public.drivers WHERE id=r.driver_id;
  rider_user:=COALESCE(r.rider_id,(SELECT ri.user_id FROM public.rider_identities ri WHERE ri.id=r.rider_identity_id));
  actor_role:=permission->>'participant_role';
  recipient:=CASE WHEN actor_role='driver' THEN rider_user ELSE d.user_id END;
  IF recipient IS NULL THEN RETURN jsonb_build_object('ok',false,'code','phone_missing'); END IF;

  SELECT * INTO a FROM public.ride_call_attempts WHERE ride_request_id=p_ride_request_id
    AND initiator_user_id=auth.uid() AND client_idempotency_key=p_idempotency_key;
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'attempt_id',a.id,'status',a.status,'idempotent_replay',true); END IF;
  IF EXISTS(SELECT 1 FROM public.ride_call_attempts x WHERE x.ride_request_id=p_ride_request_id
    AND x.status IN ('requested','queued','initiated','ringing','in_progress')) THEN
    RETURN jsonb_build_object('ok',false,'code','call_already_active');
  END IF;
  IF (SELECT count(*) FROM public.ride_call_attempts x WHERE x.ride_request_id=p_ride_request_id
      AND x.initiator_user_id=auth.uid()) >= COALESCE((c->>'max_call_attempts_per_side')::int,3) THEN
    RETURN jsonb_build_object('ok',false,'code','call_attempt_limit_reached');
  END IF;
  IF EXISTS(SELECT 1 FROM public.ride_call_attempts x WHERE x.ride_request_id=p_ride_request_id
      AND x.initiator_user_id=auth.uid() AND x.created_at > now()-make_interval(secs=>COALESCE((c->>'minimum_seconds_between_attempts')::int,30))) THEN
    RETURN jsonb_build_object('ok',false,'code','call_attempt_cooldown');
  END IF;

  SELECT * INTO s FROM public.ride_communication_sessions WHERE ride_request_id=p_ride_request_id FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO n FROM public.twilio_number_pool
      WHERE environment='production' AND status='available' AND COALESCE((capabilities->>'voice')::boolean,false)
      ORDER BY last_used_at NULLS FIRST, created_at FOR UPDATE SKIP LOCKED LIMIT 1;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'code','number_pool_exhausted'); END IF;
    UPDATE public.twilio_number_pool SET status='active',active_session_count=active_session_count+1,last_used_at=now() WHERE id=n.id;
    INSERT INTO public.ride_communication_sessions(ride_request_id,rider_user_id,driver_user_id,number_pool_id,status,call_enabled_at,ride_completed_at,call_expires_at,message_expires_at)
    VALUES(r.id,rider_user,d.user_id,n.id,'active',COALESCE(r.driver_arrived_at,now()),r.completed_at,
      CASE WHEN r.completed_at IS NULL THEN NULL ELSE r.completed_at+make_interval(mins=>COALESCE((c->>'post_ride_call_minutes')::int,10)) END,
      CASE WHEN r.completed_at IS NULL THEN NULL ELSE r.completed_at+make_interval(mins=>COALESCE((c->>'post_ride_message_minutes')::int,120)) END)
    RETURNING * INTO s;
  END IF;
  INSERT INTO public.ride_call_attempts(communication_session_id,ride_request_id,initiator_user_id,initiator_role,recipient_user_id,client_idempotency_key)
  VALUES(s.id,r.id,auth.uid(),actor_role,recipient,p_idempotency_key) RETURNING * INTO a;
  INSERT INTO public.ride_contact_attempts(ride_id,actor_type,actor_id,channel,outcome,correlation_id)
  VALUES(r.id,actor_role,auth.uid(),'masked_call','requested',a.correlation_id);
  PERFORM public.fn_ride_audit_append(r.id,'communication.masked_call_requested',auth.uid(),
    jsonb_build_object('attempt_id',a.id,'initiator_role',actor_role),actor_role,'rpc',a.correlation_id);
  RETURN jsonb_build_object('ok',true,'attempt_id',a.id,'status',a.status,'correlation_id',a.correlation_id);
EXCEPTION WHEN unique_violation THEN
  SELECT * INTO a FROM public.ride_call_attempts WHERE ride_request_id=p_ride_request_id
    AND initiator_user_id=auth.uid() AND client_idempotency_key=p_idempotency_key;
  IF FOUND THEN RETURN jsonb_build_object('ok',true,'attempt_id',a.id,'status',a.status,'idempotent_replay',true); END IF;
  RETURN jsonb_build_object('ok',false,'code','call_already_active');
END; $$;

REVOKE ALL ON FUNCTION public.fn_create_masked_call_intent(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_create_masked_call_intent(uuid,uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_ride_call_state(p_ride_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p jsonb; a public.ride_call_attempts%ROWTYPE;
BEGIN
  p:=public.fn_ride_communication_permissions(p_ride_request_id);
  IF p->>'participant_role' IS NULL THEN RETURN jsonb_build_object('ok',false,'code','not_a_participant'); END IF;
  SELECT * INTO a FROM public.ride_call_attempts WHERE ride_request_id=p_ride_request_id ORDER BY created_at DESC LIMIT 1;
  RETURN jsonb_build_object('ok',true,'permissions',p,'attempt',CASE WHEN a.id IS NULL THEN NULL ELSE jsonb_build_object(
    'id',a.id,'status',a.status,'started_at',a.started_at,'answered_at',a.answered_at,'ended_at',a.ended_at,
    'duration_seconds',a.duration_seconds,'failure_code',a.failure_code,'correlation_id',a.correlation_id) END);
END; $$;
REVOKE ALL ON FUNCTION public.fn_ride_call_state(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_ride_call_state(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_masked_call_routing_context(p_attempt_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE a public.ride_call_attempts%ROWTYPE; s public.ride_communication_sessions%ROWTYPE;
DECLARE n public.twilio_number_pool%ROWTYPE; initiator_phone text; recipient_phone text;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'service_role_required' USING ERRCODE='42501'; END IF;
  SELECT * INTO a FROM public.ride_call_attempts WHERE id=p_attempt_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'code','attempt_not_found'); END IF;
  SELECT * INTO s FROM public.ride_communication_sessions WHERE id=a.communication_session_id;
  SELECT * INTO n FROM public.twilio_number_pool WHERE id=s.number_pool_id;
  SELECT COALESCE(NULLIF(btrim(u.phone),''), NULLIF(btrim(d.phone),'')) INTO initiator_phone
    FROM auth.users u LEFT JOIN public.drivers d ON d.user_id=u.id WHERE u.id=a.initiator_user_id;
  SELECT COALESCE(NULLIF(btrim(u.phone),''), NULLIF(btrim(d.phone),'')) INTO recipient_phone
    FROM auth.users u LEFT JOIN public.drivers d ON d.user_id=u.id WHERE u.id=a.recipient_user_id;
  IF initiator_phone IS NULL OR recipient_phone IS NULL THEN
    RETURN jsonb_build_object('ok',false,'code','phone_missing');
  END IF;
  RETURN jsonb_build_object('ok',true,'attempt_id',a.id,'ride_request_id',a.ride_request_id,
    'initiator_phone',initiator_phone,'recipient_phone',recipient_phone,'masked_number',n.e164_number,
    'max_call_seconds',COALESCE((private.fn_ride_communication_config()->>'max_call_seconds')::int,300),
    'record_calls',false,'correlation_id',a.correlation_id);
END; $$;
REVOKE ALL ON FUNCTION public.fn_masked_call_routing_context(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_masked_call_routing_context(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_authorize_masked_call_attempt(p_attempt_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE a public.ride_call_attempts%ROWTYPE; r public.ride_requests%ROWTYPE;
DECLARE c jsonb := private.fn_ride_communication_config(); call_until timestamptz;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'service_role_required' USING ERRCODE='42501'; END IF;
  SELECT * INTO a FROM public.ride_call_attempts WHERE id=p_attempt_id;
  IF NOT FOUND OR a.status NOT IN ('requested','queued','initiated','ringing','in_progress') THEN
    RETURN jsonb_build_object('ok',false,'code','attempt_not_active');
  END IF;
  SELECT * INTO r FROM public.ride_requests WHERE id=a.ride_request_id;
  IF NOT COALESCE((c->>'masked_calling_enabled')::boolean,false) THEN RETURN jsonb_build_object('ok',false,'code','twilio_unavailable'); END IF;
  IF r.status IN ('driver_arrived','in_progress') THEN RETURN jsonb_build_object('ok',true,'can_call',true); END IF;
  IF r.status='completed' AND r.completed_at IS NOT NULL THEN
    call_until:=r.completed_at+make_interval(mins=>COALESCE((c->>'post_ride_call_minutes')::int,10));
    IF now()<call_until THEN RETURN jsonb_build_object('ok',true,'can_call',true,'call_available_until',call_until); END IF;
  END IF;
  RETURN jsonb_build_object('ok',false,'code',CASE WHEN r.status='completed' THEN 'call_window_expired' ELSE 'driver_not_arrived' END);
END; $$;
REVOKE ALL ON FUNCTION public.fn_authorize_masked_call_attempt(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_authorize_masked_call_attempt(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_update_masked_call_attempt(
  p_attempt_id uuid, p_status text, p_twilio_call_sid text DEFAULT NULL,
  p_parent_call_sid text DEFAULT NULL, p_duration_seconds integer DEFAULT NULL,
  p_price numeric DEFAULT NULL, p_price_unit text DEFAULT NULL,
  p_failure_code text DEFAULT NULL, p_failure_message text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE a public.ride_call_attempts%ROWTYPE; safe_duration int;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'service_role_required' USING ERRCODE='42501'; END IF;
  IF p_status NOT IN ('requested','queued','initiated','ringing','in_progress','completed','busy','no_answer','failed','canceled') THEN
    RETURN jsonb_build_object('ok',false,'code','invalid_status');
  END IF;
  safe_duration:=CASE WHEN p_duration_seconds IS NULL THEN NULL ELSE LEAST(GREATEST(p_duration_seconds,0),300) END;
  UPDATE public.ride_call_attempts SET
    status=p_status,
    twilio_call_sid=COALESCE(twilio_call_sid,NULLIF(p_twilio_call_sid,'')),
    twilio_parent_call_sid=COALESCE(twilio_parent_call_sid,NULLIF(p_parent_call_sid,'')),
    started_at=CASE WHEN p_status IN ('initiated','ringing','in_progress','completed') THEN COALESCE(started_at,now()) ELSE started_at END,
    answered_at=CASE WHEN p_status='in_progress' THEN COALESCE(answered_at,now()) ELSE answered_at END,
    ended_at=CASE WHEN p_status IN ('completed','busy','no_answer','failed','canceled') THEN COALESCE(ended_at,now()) ELSE ended_at END,
    duration_seconds=COALESCE(safe_duration,duration_seconds), price=COALESCE(p_price,price),
    price_unit=COALESCE(NULLIF(p_price_unit,''),price_unit), failure_code=COALESCE(NULLIF(p_failure_code,''),failure_code),
    failure_message=COALESCE(NULLIF(left(p_failure_message,500),''),failure_message), updated_at=now()
  WHERE id=p_attempt_id RETURNING * INTO a;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'code','attempt_not_found'); END IF;
  IF p_status IN ('completed','busy','no_answer','failed','canceled') THEN
    INSERT INTO public.ride_contact_attempts(ride_id,actor_type,actor_id,channel,outcome,correlation_id)
    VALUES(a.ride_request_id,'system',NULL,'masked_call',p_status,a.correlation_id);
  END IF;
  PERFORM public.fn_ride_audit_append(a.ride_request_id,'communication.masked_call_'||p_status,NULL,
    jsonb_build_object('attempt_id',a.id,'duration_seconds',safe_duration,'failure_code',p_failure_code),
    'system','twilio',a.correlation_id);
  RETURN jsonb_build_object('ok',true,'attempt_id',a.id,'status',a.status);
END; $$;
REVOKE ALL ON FUNCTION public.fn_update_masked_call_attempt(uuid,text,text,text,integer,numeric,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_update_masked_call_attempt(uuid,text,text,text,integer,numeric,text,text,text) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_record_twilio_voice_webhook(
  p_event_key text, p_call_sid text, p_event_type text, p_payload_redacted jsonb,
  p_signature_valid boolean, p_processing_error text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE event_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'service_role_required' USING ERRCODE='42501'; END IF;
  INSERT INTO public.twilio_voice_webhook_events(event_key,twilio_call_sid,event_type,payload_redacted,signature_valid,processed_at,processing_error)
  VALUES(left(p_event_key,250),NULLIF(p_call_sid,''),left(p_event_type,80),COALESCE(p_payload_redacted,'{}'::jsonb),p_signature_valid,
    CASE WHEN p_processing_error IS NULL THEN now() END,NULLIF(left(p_processing_error,500),''))
  ON CONFLICT(event_key) DO NOTHING RETURNING id INTO event_id;
  RETURN jsonb_build_object('ok',true,'duplicate',event_id IS NULL,'event_id',event_id);
END; $$;
REVOKE ALL ON FUNCTION public.fn_record_twilio_voice_webhook(text,text,text,jsonb,boolean,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_record_twilio_voice_webhook(text,text,text,jsonb,boolean,text) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_admin_os_communications_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor public.admin_users; latest public.twilio_usage_snapshots%ROWTYPE;
BEGIN
  actor:=private.fn_admin_os_actor('overview.read');
  SELECT * INTO latest FROM public.twilio_usage_snapshots ORDER BY captured_at DESC LIMIT 1;
  RETURN jsonb_build_object(
    'generated_at',now(),
    'pool',jsonb_build_object(
      'total',(SELECT count(*) FROM public.twilio_number_pool),
      'available',(SELECT count(*) FROM public.twilio_number_pool WHERE status='available'),
      'active',(SELECT count(*) FROM public.twilio_number_pool WHERE status='active'),
      'cooldown',(SELECT count(*) FROM public.twilio_number_pool WHERE status='cooldown'),
      'disabled',(SELECT count(*) FROM public.twilio_number_pool WHERE status IN ('disabled','failed')),
      'allocation_failures',(SELECT count(*) FROM public.ride_call_attempts WHERE failure_code='number_pool_exhausted' AND created_at>=now()-interval '24 hours')
    ),
    'calls',jsonb_build_object(
      'today',(SELECT count(*) FROM public.ride_call_attempts WHERE created_at>=date_trunc('day',now())),
      'answered',(SELECT count(*) FROM public.ride_call_attempts WHERE answered_at>=date_trunc('day',now())),
      'failed',(SELECT count(*) FROM public.ride_call_attempts WHERE status IN ('failed','busy','no_answer') AND created_at>=date_trunc('day',now())),
      'connected_minutes',ROUND(COALESCE((SELECT sum(duration_seconds) FROM public.ride_call_attempts WHERE created_at>=date_trunc('day',now())),0)/60.0,1),
      'average_seconds',ROUND(COALESCE((SELECT avg(duration_seconds) FROM public.ride_call_attempts WHERE duration_seconds IS NOT NULL AND created_at>=date_trunc('day',now())),0),1),
      'five_minute_terminations',(SELECT count(*) FROM public.ride_call_attempts WHERE duration_seconds>=299 AND created_at>=date_trunc('day',now())),
      'rider_initiated',(SELECT count(*) FROM public.ride_call_attempts WHERE initiator_role='rider' AND created_at>=date_trunc('day',now())),
      'driver_initiated',(SELECT count(*) FROM public.ride_call_attempts WHERE initiator_role='driver' AND created_at>=date_trunc('day',now()))
    ),
    'usage',CASE WHEN latest.id IS NULL THEN NULL ELSE jsonb_build_object(
      'balance_amount',latest.balance_amount,'balance_currency',latest.balance_currency,
      'voice_cost_today',latest.voice_cost_today,'number_cost_month',latest.number_cost_month,
      'captured_at',latest.captured_at) END
  );
END; $$;
REVOKE ALL ON FUNCTION public.fn_admin_os_communications_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_os_communications_overview() TO authenticated;

-- Extend the existing canonical in-app chat command for the configured
-- post-ride window. Twilio SMS is deliberately not introduced.
CREATE OR REPLACE FUNCTION public.fn_ride_message_window_open(p_ride_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ride_requests%ROWTYPE; c jsonb:=private.fn_ride_communication_config();
BEGIN
  SELECT * INTO r FROM public.ride_requests WHERE id=p_ride_id;
  IF NOT FOUND THEN RETURN false; END IF;
  RETURN r.status IN ('accepted','assigned','driver_found','driver_en_route','arrived','driver_arrived','in_progress')
    OR (r.status='completed' AND r.completed_at IS NOT NULL
      AND now()<r.completed_at+make_interval(mins=>COALESCE((c->>'post_ride_message_minutes')::int,120)));
END; $$;
REVOKE ALL ON FUNCTION public.fn_ride_message_window_open(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_ride_message_window_open(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.fn_send_ride_message(
  p_ride_id uuid, p_idempotency_key text, p_content text,
  p_message_type text DEFAULT 'text'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, private AS $$
DECLARE
  v_actor jsonb; v_sender_type text; v_sender_id uuid; v_status text;
  v_content text; v_message_type text; v_key text; v_conversation_id uuid;
  v_message public.messages%ROWTYPE; v_inserted boolean:=false;
  v_completed_at timestamptz; v_message_until timestamptz;
  v_config jsonb:=private.fn_ride_communication_config();
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'code','unauthorized'); END IF;
  v_content:=btrim(COALESCE(p_content,''));
  v_message_type:=lower(btrim(COALESCE(p_message_type,'text')));
  v_key:=btrim(COALESCE(p_idempotency_key,''));
  IF p_ride_id IS NULL OR length(v_content)<1 OR length(v_content)>2000
     OR v_message_type NOT IN ('text','ping') OR v_key !~ '^[A-Za-z0-9_-]{16,128}$' THEN
    RETURN jsonb_build_object('ok',false,'code','invalid_message');
  END IF;
  v_actor:=private.fn_ride_chat_actor(p_ride_id);
  IF v_actor IS NULL THEN RETURN jsonb_build_object('ok',false,'code','not_participant'); END IF;
  v_sender_type:=v_actor->>'sender_type'; v_sender_id:=(v_actor->>'sender_id')::uuid;
  v_status:=v_actor->>'ride_status'; v_conversation_id:=NULLIF(v_actor->>'conversation_id','')::uuid;
  SELECT completed_at INTO v_completed_at FROM public.ride_requests WHERE id=p_ride_id;
  IF v_completed_at IS NOT NULL THEN
    v_message_until:=v_completed_at+make_interval(mins=>COALESCE((v_config->>'post_ride_message_minutes')::int,120));
  END IF;
  IF v_status NOT IN ('accepted','assigned','driver_found','driver_en_route','arrived','driver_arrived','in_progress')
     AND NOT (v_status='completed' AND now()<v_message_until) THEN
    RETURN jsonb_build_object('ok',false,'code','ride_chat_closed','ride_status',v_status,
      'message_available_until',v_message_until);
  END IF;
  IF EXISTS(SELECT 1 FROM public.ride_chat_blocks b WHERE b.ride_id=p_ride_id AND (
      (b.blocker_type=v_sender_type AND b.blocker_id=v_sender_id::text)
      OR (b.blocked_type=v_sender_type AND b.blocked_id=v_sender_id::text))) THEN
    RETURN jsonb_build_object('ok',false,'code','chat_blocked');
  END IF;
  INSERT INTO public.messages(ride_request_id,conversation_id,sender_type,sender_id,content,message_type,client_idempotency_key)
  VALUES(p_ride_id,v_conversation_id,v_sender_type,v_sender_id,v_content,v_message_type,v_key)
  ON CONFLICT(ride_request_id,sender_type,sender_id,client_idempotency_key)
    WHERE client_idempotency_key IS NOT NULL DO NOTHING RETURNING * INTO v_message;
  v_inserted:=FOUND;
  IF NOT v_inserted THEN
    SELECT * INTO v_message FROM public.messages m WHERE m.ride_request_id=p_ride_id
      AND m.sender_type=v_sender_type AND m.sender_id=v_sender_id AND m.client_idempotency_key=v_key;
    IF NOT FOUND OR v_message.content IS DISTINCT FROM v_content OR v_message.message_type IS DISTINCT FROM v_message_type THEN
      RETURN jsonb_build_object('ok',false,'code','idempotency_conflict');
    END IF;
  END IF;
  IF v_inserted THEN
    PERFORM public.fn_ride_audit_append(p_ride_id,'chat.message_sent',v_sender_id,
      jsonb_build_object('message_id',v_message.id,'message_type',v_message_type,'conversation_id',v_message.conversation_id),
      v_sender_type,'rpc',v_message.id);
  END IF;
  RETURN jsonb_build_object('ok',true,'code',CASE WHEN v_inserted THEN 'sent' ELSE 'already_sent' END,
    'message',to_jsonb(v_message),'message_available_until',v_message_until);
END; $$;
REVOKE ALL ON FUNCTION public.fn_send_ride_message(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_send_ride_message(uuid,text,text,text) TO authenticated;

DROP POLICY IF EXISTS messages_insert_participant ON public.messages;
CREATE POLICY messages_insert_participant ON public.messages FOR INSERT TO authenticated WITH CHECK (
  EXISTS(SELECT 1 FROM public.ride_requests rr WHERE rr.id=messages.ride_request_id
    AND public.fn_ride_message_window_open(rr.id)
    AND ((messages.sender_type::text='driver' AND messages.sender_id=auth.uid()
          AND rr.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id=auth.uid()))
      OR (messages.sender_type::text='rider'
          AND (rr.rider_id=auth.uid() OR rr.rider_identity_id IN (SELECT ri.id FROM public.rider_identities ri WHERE ri.user_id=auth.uid())
            OR rr.rider_token IN (SELECT rs.session_token FROM public.rider_sessions rs WHERE rs.user_id=auth.uid()))
          AND (messages.sender_id=auth.uid() OR messages.sender_id=rr.rider_identity_id))))
  AND NOT EXISTS(SELECT 1 FROM public.ride_chat_blocks b WHERE b.ride_id=messages.ride_request_id
    AND ((b.blocker_type=messages.sender_type::text AND b.blocker_id=messages.sender_id::text)
      OR (b.blocked_type=messages.sender_type::text AND b.blocked_id=messages.sender_id::text)))
);

COMMENT ON TABLE public.ride_communication_sessions IS 'Canonical ride-scoped masked communication lifecycle. No real phone numbers.';
COMMENT ON TABLE public.ride_call_attempts IS 'Operational Twilio call metadata. Real participant numbers are deliberately absent.';
COMMENT ON FUNCTION public.fn_ride_communication_permissions(uuid) IS 'Canonical Rider/Driver call and message authorization contract.';
