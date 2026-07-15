-- Lifecycle synchronization, pool cooldown and operational alerts for masked calling.

UPDATE public.app_config
SET value = (value::jsonb || '{"minimum_available_numbers":2,"call_failure_alert_percent":35,"twilio_balance_warning":25,"twilio_balance_critical":10}'::jsonb)::text
WHERE key='ride_communication_config';

CREATE TABLE IF NOT EXISTS public.ride_communication_operational_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dedupe_key text NOT NULL UNIQUE,
  alert_type text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('warning','critical','emergency')),
  ride_request_id uuid REFERENCES public.ride_requests(id) ON DELETE SET NULL,
  call_attempt_id uuid REFERENCES public.ride_call_attempts(id) ON DELETE SET NULL,
  correlation_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  first_detected_at timestamptz NOT NULL DEFAULT now(),
  last_detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
ALTER TABLE public.ride_communication_operational_alerts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ride_communication_operational_alerts FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.ride_communication_operational_alerts TO service_role;

CREATE OR REPLACE FUNCTION private.trg_sync_ride_communication_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE c jsonb:=private.fn_ride_communication_config();
BEGIN
  IF NEW.completed_at IS NOT NULL AND (OLD.completed_at IS DISTINCT FROM NEW.completed_at OR OLD.status IS DISTINCT FROM NEW.status) THEN
    UPDATE public.ride_communication_sessions SET
      ride_completed_at=NEW.completed_at,
      call_expires_at=NEW.completed_at+make_interval(mins=>COALESCE((c->>'post_ride_call_minutes')::int,10)),
      message_expires_at=NEW.completed_at+make_interval(mins=>COALESCE((c->>'post_ride_message_minutes')::int,120)),
      status='active',updated_at=now()
    WHERE ride_request_id=NEW.id AND status NOT IN ('closed','suspended');
  ELSIF NEW.status IN ('cancelled','canceled','expired') AND OLD.status IS DISTINCT FROM NEW.status THEN
    UPDATE public.ride_communication_sessions SET status='closed',closed_at=now(),close_reason='ride_'||NEW.status,updated_at=now()
    WHERE ride_request_id=NEW.id AND status<>'closed';
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.trg_sync_ride_communication_lifecycle() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_sync_ride_communication_lifecycle ON public.ride_requests;
CREATE TRIGGER trg_sync_ride_communication_lifecycle
AFTER UPDATE OF status,completed_at ON public.ride_requests
FOR EACH ROW EXECUTE FUNCTION private.trg_sync_ride_communication_lifecycle();

CREATE OR REPLACE FUNCTION private.trg_suspend_blocked_ride_communication()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.ride_communication_sessions SET status='suspended',closed_at=now(),close_reason='participant_blocked',updated_at=now()
  WHERE ride_request_id=NEW.ride_id AND status NOT IN ('closed','suspended');
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.trg_suspend_blocked_ride_communication() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_suspend_blocked_ride_communication ON public.ride_chat_blocks;
CREATE TRIGGER trg_suspend_blocked_ride_communication
AFTER INSERT ON public.ride_chat_blocks FOR EACH ROW
EXECUTE FUNCTION private.trg_suspend_blocked_ride_communication();

CREATE OR REPLACE FUNCTION public.fn_maintain_ride_communication_pool()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE c jsonb:=private.fn_ride_communication_config(); closed_count int:=0; released_count int:=0;
BEGIN
  IF auth.role() NOT IN ('service_role','postgres') AND current_user NOT IN ('postgres','supabase_admin') THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE='42501';
  END IF;
  WITH expired AS (
    UPDATE public.ride_communication_sessions SET status='closed',closed_at=COALESCE(closed_at,now()),
      close_reason=COALESCE(close_reason,'message_window_expired'),updated_at=now()
    WHERE status IN ('active','message_only','call_expired') AND message_expires_at IS NOT NULL AND now()>=message_expires_at
    RETURNING number_pool_id
  ), released AS (
    UPDATE public.twilio_number_pool n SET status='cooldown',active_session_count=GREATEST(n.active_session_count-1,0),
      reserved_until=now()+make_interval(mins=>COALESCE((c->>'number_cooldown_minutes')::int,45)),last_used_at=now()
    WHERE n.id IN (SELECT number_pool_id FROM expired WHERE number_pool_id IS NOT NULL) RETURNING n.id
  ) SELECT (SELECT count(*) FROM expired),(SELECT count(*) FROM released) INTO closed_count,released_count;
  UPDATE public.ride_communication_sessions SET status='message_only',updated_at=now()
    WHERE status='active' AND call_expires_at IS NOT NULL AND now()>=call_expires_at
      AND (message_expires_at IS NULL OR now()<message_expires_at);
  UPDATE public.twilio_number_pool SET status='available',reserved_until=NULL
    WHERE status='cooldown' AND reserved_until IS NOT NULL AND now()>=reserved_until
      AND disabled_at IS NULL AND health_state NOT IN ('failed');
  RETURN jsonb_build_object('ok',true,'sessions_closed',closed_count,'numbers_cooled_down',released_count);
END; $$;
REVOKE ALL ON FUNCTION public.fn_maintain_ride_communication_pool() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_maintain_ride_communication_pool() TO service_role;

CREATE OR REPLACE FUNCTION public.fn_scan_ride_communication_alerts()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE c jsonb:=private.fn_ride_communication_config(); inserted_count int:=0; feature_on boolean;
DECLARE total_calls int; failed_calls int; available_count int; latest public.twilio_usage_snapshots%ROWTYPE;
BEGIN
  IF auth.role() NOT IN ('service_role','postgres') AND current_user NOT IN ('postgres','supabase_admin') THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE='42501';
  END IF;
  feature_on:=COALESCE((c->>'masked_calling_enabled')::boolean,false);
  SELECT count(*) INTO available_count FROM public.twilio_number_pool WHERE environment='production' AND status='available';
  IF feature_on AND available_count<COALESCE((c->>'minimum_available_numbers')::int,2) THEN
    INSERT INTO public.ride_communication_operational_alerts(dedupe_key,alert_type,severity,details)
    VALUES('twilio-number-pool-low','twilio_number_pool_low',CASE WHEN available_count=0 THEN 'emergency' ELSE 'warning' END,
      jsonb_build_object('available_numbers',available_count,'minimum',COALESCE((c->>'minimum_available_numbers')::int,2)))
    ON CONFLICT(dedupe_key) DO UPDATE SET last_detected_at=now(),severity=EXCLUDED.severity,details=EXCLUDED.details,resolved_at=NULL;
    inserted_count:=inserted_count+1;
  ELSE UPDATE public.ride_communication_operational_alerts SET resolved_at=COALESCE(resolved_at,now()) WHERE dedupe_key='twilio-number-pool-low' AND resolved_at IS NULL;
  END IF;
  INSERT INTO public.ride_communication_operational_alerts(dedupe_key,alert_type,severity,details)
  SELECT 'twilio-signature-failure:'||date_trunc('hour',received_at)::text,'twilio_signature_failure','critical',
    jsonb_build_object('failures',count(*),'hour',date_trunc('hour',received_at))
  FROM public.twilio_voice_webhook_events WHERE NOT signature_valid AND received_at>=now()-interval '1 hour'
  GROUP BY date_trunc('hour',received_at)
  ON CONFLICT(dedupe_key) DO UPDATE SET last_detected_at=now(),details=EXCLUDED.details,resolved_at=NULL;
  GET DIAGNOSTICS inserted_count=ROW_COUNT;
  SELECT count(*),count(*) FILTER(WHERE status IN ('failed','busy','no_answer')) INTO total_calls,failed_calls
  FROM public.ride_call_attempts WHERE created_at>=now()-interval '1 hour';
  IF total_calls>=5 AND failed_calls*100.0/total_calls>=COALESCE((c->>'call_failure_alert_percent')::numeric,35) THEN
    INSERT INTO public.ride_communication_operational_alerts(dedupe_key,alert_type,severity,details)
    VALUES('twilio-call-failure-rate','twilio_call_failure_rate','warning',jsonb_build_object('calls',total_calls,'failures',failed_calls))
    ON CONFLICT(dedupe_key) DO UPDATE SET last_detected_at=now(),details=EXCLUDED.details,resolved_at=NULL;
  ELSE UPDATE public.ride_communication_operational_alerts SET resolved_at=COALESCE(resolved_at,now()) WHERE dedupe_key='twilio-call-failure-rate' AND resolved_at IS NULL;
  END IF;
  SELECT * INTO latest FROM public.twilio_usage_snapshots ORDER BY captured_at DESC LIMIT 1;
  IF latest.balance_amount IS NOT NULL AND latest.balance_amount<COALESCE((c->>'twilio_balance_warning')::numeric,25) THEN
    INSERT INTO public.ride_communication_operational_alerts(dedupe_key,alert_type,severity,details)
    VALUES('twilio-balance-low','twilio_balance_low',CASE WHEN latest.balance_amount<COALESCE((c->>'twilio_balance_critical')::numeric,10) THEN 'critical' ELSE 'warning' END,
      jsonb_build_object('balance',latest.balance_amount,'currency',latest.balance_currency,'captured_at',latest.captured_at))
    ON CONFLICT(dedupe_key) DO UPDATE SET last_detected_at=now(),severity=EXCLUDED.severity,details=EXCLUDED.details,resolved_at=NULL;
  END IF;
  RETURN inserted_count;
END; $$;
REVOKE ALL ON FUNCTION public.fn_scan_ride_communication_alerts() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fn_scan_ride_communication_alerts() TO service_role;

CREATE OR REPLACE FUNCTION public.fn_admin_os_communication_alerts(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor public.admin_users;
BEGIN
  actor:=private.fn_admin_os_actor('overview.read');
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object(
    'id',a.id,'alert_type',a.alert_type,'severity',a.severity,
    'ride_request_id',a.ride_request_id,'call_attempt_id',a.call_attempt_id,
    'correlation_id',a.correlation_id,'details',a.details,
    'first_detected_at',a.first_detected_at,'last_detected_at',a.last_detected_at
  ) ORDER BY a.last_detected_at DESC) FROM (
    SELECT * FROM public.ride_communication_operational_alerts
    WHERE resolved_at IS NULL ORDER BY last_detected_at DESC LIMIT LEAST(GREATEST(p_limit,1),100)
  ) a),'[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.fn_admin_os_communication_alerts(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_os_communication_alerts(integer) TO authenticated;

DO $schedule$
BEGIN
  IF to_regnamespace('cron') IS NOT NULL THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname='ride-communication-maintenance';
    PERFORM cron.schedule('ride-communication-maintenance','*/5 * * * *',
      'select public.fn_maintain_ride_communication_pool(); select public.fn_scan_ride_communication_alerts();');
  END IF;
END;
$schedule$;
