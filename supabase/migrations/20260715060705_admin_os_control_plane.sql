-- HeyCaby Admin OS control plane.
-- The Admin website consumes these contracts; it never writes domain tables directly.

CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS public.admin_driver_restrictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  imposed_by uuid NOT NULL REFERENCES auth.users(id),
  lifted_by uuid REFERENCES auth.users(id),
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 8 AND 1000),
  previous_state jsonb NOT NULL,
  imposed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  lifted_at timestamptz,
  lift_reason text,
  CHECK (expires_at IS NULL OR expires_at > imposed_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS admin_driver_restrictions_one_active_idx
  ON public.admin_driver_restrictions (driver_id)
  WHERE lifted_at IS NULL;

CREATE INDEX IF NOT EXISTS admin_driver_restrictions_driver_history_idx
  ON public.admin_driver_restrictions (driver_id, imposed_at DESC);

ALTER TABLE public.admin_driver_restrictions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.admin_driver_restrictions FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.admin_driver_restrictions TO service_role;

CREATE OR REPLACE FUNCTION private.fn_admin_os_actor(
  p_permission text DEFAULT NULL,
  p_require_aal2 boolean DEFAULT false
)
RETURNS public.admin_users
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, private, auth, pg_temp
AS $$
DECLARE
  v_admin public.admin_users%ROWTYPE;
  v_claims jsonb := COALESCE(NULLIF(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
  v_aal text := COALESCE(v_claims->>'aal', 'aal1');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'admin_auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_admin
  FROM public.admin_users au
  WHERE au.user_id = auth.uid() AND au.is_active
  LIMIT 1;

  IF v_admin.id IS NULL OR v_admin.role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'admin_not_authorized' USING ERRCODE = '42501';
  END IF;

  IF p_permission IS NOT NULL
     AND v_admin.role <> 'super_admin'
     AND NOT (p_permission = ANY(COALESCE(v_admin.permissions, ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'admin_permission_required:%', p_permission USING ERRCODE = '42501';
  END IF;

  IF p_require_aal2 AND v_aal <> 'aal2' THEN
    RAISE EXCEPTION 'admin_mfa_required' USING ERRCODE = '42501';
  END IF;

  RETURN v_admin;
END;
$$;

CREATE OR REPLACE FUNCTION private.fn_admin_os_audit(
  p_actor public.admin_users,
  p_action text,
  p_resource_type text,
  p_resource_id text,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  INSERT INTO public.admin_activity_logs (
    admin_user_id, action, resource_type, resource_id, details
  ) VALUES (
    p_actor.id, p_action, p_resource_type, p_resource_id, COALESCE(p_details, '{}'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION private.fn_admin_os_actor(text, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.fn_admin_os_audit(public.admin_users, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_admin_os_session()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, private, auth, pg_temp
AS $$
DECLARE
  v_actor public.admin_users;
  v_claims jsonb := COALESCE(NULLIF(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
BEGIN
  v_actor := private.fn_admin_os_actor();
  RETURN jsonb_build_object(
    'id', v_actor.id,
    'user_id', v_actor.user_id,
    'email', v_actor.email,
    'full_name', v_actor.full_name,
    'role', v_actor.role,
    'permissions', COALESCE(to_jsonb(v_actor.permissions), '[]'::jsonb),
    'aal', COALESCE(v_claims->>'aal', 'aal1'),
    'mfa_required_for_commands', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_overview()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, private, pg_temp
AS $$
DECLARE
  v_actor public.admin_users;
  v_result jsonb;
BEGIN
  v_actor := private.fn_admin_os_actor('overview.read');

  SELECT jsonb_build_object(
    'generated_at', now(),
    'drivers', jsonb_build_object(
      'total', count(*),
      'available', count(*) FILTER (WHERE d.status = 'available'),
      'on_ride', count(*) FILTER (WHERE d.status = 'on_ride'),
      'on_break', count(*) FILTER (WHERE d.status = 'on_break'),
      'offline', count(*) FILTER (WHERE d.status = 'offline'),
      'verified', count(*) FILTER (WHERE d.profile_status = 'verified'),
      'restricted', count(*) FILTER (WHERE d.profile_status = 'suspended' OR d.account_status <> 'active')
    )
  ) INTO v_result FROM public.drivers d;

  v_result := v_result || jsonb_build_object(
    'rides', (SELECT jsonb_build_object(
      'total', count(*),
      'today', count(*) FILTER (WHERE rr.created_at >= date_trunc('day', now())),
      'active', count(*) FILTER (WHERE rr.status IN ('accepted','driver_arrived','in_progress')),
      'completed_today', count(*) FILTER (WHERE rr.status = 'completed' AND rr.completed_at >= date_trunc('day', now())),
      'cancelled_today', count(*) FILTER (WHERE rr.status = 'cancelled' AND rr.cancelled_at >= date_trunc('day', now()))
    ) FROM public.ride_requests rr),
    'operations', jsonb_build_object(
      'open_support', (SELECT count(*) FROM public.tickets t WHERE t.status NOT IN ('resolved','closed')),
      'urgent_support', (SELECT count(*) FROM public.tickets t WHERE t.status NOT IN ('resolved','closed') AND t.priority IN ('urgent','high')),
      'open_reports', (SELECT count(*) FROM public.ride_reports r WHERE NOT COALESCE(r.resolved, false)),
      'active_payment_alerts', (SELECT count(*) FROM public.ride_payment_operational_alerts a WHERE a.resolved_at IS NULL)
    ),
    'finance', jsonb_build_object(
      'platform_commission_cents', (SELECT COALESCE(sum(rr.platform_fee_cents),0) FROM public.ride_requests rr WHERE rr.status='completed'),
      'completed_ride_value_eur', (SELECT COALESCE(sum(COALESCE(rr.final_fare, rr.total_amount_eur, rr.offered_fare, rr.estimated_price)),0) FROM public.ride_requests rr WHERE rr.status='completed'),
      'prepaid_volume_cents', (SELECT COALESCE(sum(rp.amount_cents),0) FROM public.ride_payments rp WHERE rp.state IN ('paid','routed','partially_refunded','refunded')),
      'outstanding_platform_balance_cents', (SELECT COALESCE(sum(greatest(dpb.outstanding_cents,0)),0) FROM public.driver_platform_balance dpb)
    )
  );
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_drivers(
  p_search text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, private, pg_temp
AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('drivers.read');
  RETURN COALESCE((
    SELECT jsonb_agg(to_jsonb(x) ORDER BY x.last_active DESC NULLS LAST)
    FROM (
      SELECT d.id, d.full_name,
        CASE WHEN d.email IS NULL THEN NULL ELSE left(d.email,2) || '***@' || split_part(d.email,'@',2) END AS email,
        CASE WHEN d.phone IS NULL THEN NULL ELSE '***' || right(d.phone,4) END AS phone,
        d.status::text, d.profile_status::text, d.compliance_status, d.account_status,
        d.rating, d.trip_count, d.last_active, d.updated_at,
        city.name AS city, dl.updated_at AS location_fresh_at,
        EXISTS (SELECT 1 FROM public.admin_driver_restrictions adr WHERE adr.driver_id=d.id AND adr.lifted_at IS NULL) AS restricted
      FROM public.drivers d
      LEFT JOIN public.driver_locations dl ON dl.driver_id=d.id
      LEFT JOIN public.cities city ON city.id=dl.current_city_id
      WHERE (p_search IS NULL OR btrim(p_search)='' OR d.full_name ILIKE '%'||p_search||'%' OR d.email ILIKE '%'||p_search||'%' OR d.phone ILIKE '%'||p_search||'%')
        AND (p_status IS NULL OR p_status='' OR d.status::text=p_status OR d.profile_status::text=p_status OR d.account_status=p_status)
      ORDER BY d.last_active DESC NULLS LAST
      LIMIT least(greatest(p_limit,1),100) OFFSET greatest(p_offset,0)
    ) x
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_driver_detail(p_driver_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_temp
AS $$
DECLARE v_actor public.admin_users; v_result jsonb;
BEGIN
  v_actor := private.fn_admin_os_actor('privacy.pii');
  IF char_length(btrim(COALESCE(p_reason,''))) < 8 THEN RAISE EXCEPTION 'access_reason_required'; END IF;
  SELECT jsonb_build_object(
    'driver', to_jsonb(d) - 'user_id',
    'compliance', to_jsonb(c),
    'platform_balance', to_jsonb(pb),
    'restriction', to_jsonb(ar)
  ) INTO v_result
  FROM public.drivers d
  LEFT JOIN public.driver_compliance_dashboard c ON c.id=d.id
  LEFT JOIN public.driver_platform_balance pb ON pb.driver_id=d.id
  LEFT JOIN public.admin_driver_restrictions ar ON ar.driver_id=d.id AND ar.lifted_at IS NULL
  WHERE d.id=p_driver_id;
  IF v_result IS NULL THEN RAISE EXCEPTION 'driver_not_found'; END IF;
  PERFORM private.fn_admin_os_audit(v_actor,'privacy.driver_viewed','driver',p_driver_id::text,jsonb_build_object('reason',btrim(p_reason)));
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_rides(p_status text DEFAULT NULL, p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('rides.read');
  RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM (
    SELECT rr.id, rr.status, rr.booking_mode::text, rr.is_scheduled, rr.scheduled_pickup_at,
      rr.payment_method, rr.payment_status, rr.offered_fare, rr.final_fare, rr.currency,
      rr.driver_id, d.full_name AS driver_name, rr.created_at, rr.accepted_at, rr.started_at, rr.completed_at,
      CASE WHEN rr.pickup_address IS NULL THEN NULL ELSE split_part(rr.pickup_address,',',1) END AS pickup_area,
      CASE WHEN rr.destination_address IS NULL THEN NULL ELSE split_part(rr.destination_address,',',1) END AS destination_area
    FROM public.ride_requests rr LEFT JOIN public.drivers d ON d.id=rr.driver_id
    WHERE p_status IS NULL OR p_status='' OR rr.status=p_status
    ORDER BY rr.created_at DESC LIMIT least(greatest(p_limit,1),100)
  ) x),'[]'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_support_queue(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('support.read');
  RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.last_message_at DESC NULLS LAST) FROM (
    SELECT t.id,t.ticket_number,t.user_type,t.category,t.priority,t.status,t.ride_request_id,
      t.ai_summary,t.refund_requested,t.driver_flagged,t.created_at,t.updated_at,t.last_message_at,t.message_count
    FROM public.tickets t ORDER BY (t.status NOT IN ('resolved','closed')) DESC,
      CASE t.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END, t.last_message_at DESC NULLS LAST
    LIMIT least(greatest(p_limit,1),100)
  ) x),'[]'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_reports(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('reports.read');
  RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM (
    SELECT r.id,r.ride_request_id,r.reporter_type,r.reason,r.is_reviewed,r.created_at,r.driver_id,
      r.admin_response,r.admin_responded_at,r.resolved,r.status
    FROM public.ride_reports r ORDER BY COALESCE(r.resolved,false),r.created_at DESC
    LIMIT least(greatest(p_limit,1),100)
  ) x),'[]'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_payments(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('payments.read');
  RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM (
    SELECT rp.id,rp.ride_id,rp.driver_id,rp.provider,rp.state,rp.amount_cents,rp.currency,
      rp.platform_fee_cents,rp.driver_route_cents,rp.correlation_id,rp.failure_code,rp.paid_at,
      rp.refunded_cents,rp.routed_at,rp.created_at
    FROM public.ride_payments rp ORDER BY rp.created_at DESC LIMIT least(greatest(p_limit,1),100)
  ) x),'[]'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_audit_log(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('audit.read');
  RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM (
    SELECT l.id,l.action,l.resource_type,l.resource_id,l.details,l.created_at,
      au.full_name AS admin_name,au.email AS admin_email
    FROM public.admin_activity_logs l LEFT JOIN public.admin_users au ON au.id=l.admin_user_id
    ORDER BY l.created_at DESC LIMIT least(greatest(p_limit,1),250)
  ) x),'[]'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_set_driver_restriction(
  p_driver_id uuid, p_restricted boolean, p_reason text, p_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users; v_driver public.drivers; v_restriction public.admin_driver_restrictions;
BEGIN
  v_actor := private.fn_admin_os_actor('drivers.restrict', true);
  IF char_length(btrim(COALESCE(p_reason,''))) < 8 THEN RAISE EXCEPTION 'restriction_reason_required'; END IF;
  SELECT * INTO v_driver FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
  IF v_driver.id IS NULL THEN RAISE EXCEPTION 'driver_not_found'; END IF;

  SELECT * INTO v_restriction FROM public.admin_driver_restrictions
  WHERE driver_id=p_driver_id AND lifted_at IS NULL FOR UPDATE;

  IF p_restricted THEN
    IF v_restriction.id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'unchanged',true,'restriction_id',v_restriction.id); END IF;
    INSERT INTO public.admin_driver_restrictions(driver_id,imposed_by,reason,expires_at,previous_state)
    VALUES(p_driver_id,auth.uid(),btrim(p_reason),p_expires_at,jsonb_build_object(
      'status',v_driver.status::text,'profile_status',v_driver.profile_status::text,
      'compliance_status',v_driver.compliance_status,'account_status',v_driver.account_status,
      'compliance_suspended_reason',v_driver.compliance_suspended_reason
    )) RETURNING * INTO v_restriction;
    UPDATE public.drivers SET status='offline',profile_status='suspended',compliance_status='suspended',
      account_status='suspended',compliance_suspended_reason=btrim(p_reason),updated_at=now() WHERE id=p_driver_id;
    PERFORM private.fn_admin_os_audit(v_actor,'driver.restricted','driver',p_driver_id::text,
      jsonb_build_object('reason',btrim(p_reason),'expires_at',p_expires_at,'restriction_id',v_restriction.id));
  ELSE
    IF v_restriction.id IS NULL THEN RETURN jsonb_build_object('ok',true,'unchanged',true); END IF;
    UPDATE public.drivers SET
      status=COALESCE((v_restriction.previous_state->>'status')::driver_status,'offline'),
      profile_status=COALESCE((v_restriction.previous_state->>'profile_status')::profile_status,'pending_review'),
      compliance_status=COALESCE(v_restriction.previous_state->>'compliance_status','incomplete'),
      account_status=COALESCE(v_restriction.previous_state->>'account_status','active'),
      compliance_suspended_reason=v_restriction.previous_state->>'compliance_suspended_reason',updated_at=now()
    WHERE id=p_driver_id;
    UPDATE public.admin_driver_restrictions SET lifted_by=auth.uid(),lifted_at=now(),lift_reason=btrim(p_reason)
    WHERE id=v_restriction.id;
    PERFORM private.fn_admin_os_audit(v_actor,'driver.restriction_lifted','driver',p_driver_id::text,
      jsonb_build_object('reason',btrim(p_reason),'restriction_id',v_restriction.id));
  END IF;
  RETURN jsonb_build_object('ok',true,'restricted',p_restricted,'restriction_id',v_restriction.id);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_resolve_ticket(
  p_ticket_id uuid, p_outcome text, p_summary text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('support.resolve', true);
  IF char_length(btrim(COALESCE(p_summary,''))) < 8 THEN RAISE EXCEPTION 'resolution_summary_required'; END IF;
  UPDATE public.tickets SET status='resolved',resolved_by=v_actor.email,resolved_at=now(),updated_at=now(),
    resolution_outcome=NULLIF(btrim(p_outcome),''),resolution_summary=btrim(p_summary) WHERE id=p_ticket_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ticket_not_found'; END IF;
  PERFORM private.fn_admin_os_audit(v_actor,'support.ticket_resolved','ticket',p_ticket_id::text,
    jsonb_build_object('outcome',p_outcome,'summary',p_summary));
  RETURN jsonb_build_object('ok',true);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_resolve_report(
  p_report_id uuid, p_response text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users;
BEGIN
  v_actor := private.fn_admin_os_actor('reports.resolve', true);
  IF char_length(btrim(COALESCE(p_response,''))) < 8 THEN RAISE EXCEPTION 'report_response_required'; END IF;
  UPDATE public.ride_reports SET is_reviewed=true,resolved=true,status='resolved',admin_response=btrim(p_response),admin_responded_at=now()
  WHERE id=p_report_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'report_not_found'; END IF;
  PERFORM private.fn_admin_os_audit(v_actor,'report.resolved','ride_report',p_report_id::text,jsonb_build_object('response',p_response));
  RETURN jsonb_build_object('ok',true);
END; $$;

CREATE OR REPLACE FUNCTION public.fn_admin_os_log_communication(
  p_channel text, p_target text, p_title text, p_body text, p_result jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,private,pg_temp AS $$
DECLARE v_actor public.admin_users; v_id uuid := gen_random_uuid();
BEGIN
  v_actor := private.fn_admin_os_actor('communications.send', true);
  IF p_channel NOT IN ('push','email') OR p_target NOT IN ('all','riders','drivers') THEN RAISE EXCEPTION 'invalid_communication_target'; END IF;
  IF char_length(btrim(COALESCE(p_title,''))) NOT BETWEEN 2 AND 120 OR char_length(btrim(COALESCE(p_body,''))) NOT BETWEEN 2 AND 500 THEN RAISE EXCEPTION 'invalid_communication_content'; END IF;
  PERFORM private.fn_admin_os_audit(v_actor,'communication.sent','communication',v_id::text,jsonb_build_object(
    'channel',p_channel,'target',p_target,'title',btrim(p_title),'body',btrim(p_body),'result',COALESCE(p_result,'{}'::jsonb)
  ));
  RETURN jsonb_build_object('ok',true,'communication_id',v_id);
END; $$;

DO $$
DECLARE fn text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'fn_admin_os_session()','fn_admin_os_overview()','fn_admin_os_drivers(text,text,integer,integer)',
    'fn_admin_os_driver_detail(uuid,text)','fn_admin_os_rides(text,integer)','fn_admin_os_support_queue(integer)',
    'fn_admin_os_reports(integer)','fn_admin_os_payments(integer)','fn_admin_os_audit_log(integer)',
    'fn_admin_os_set_driver_restriction(uuid,boolean,text,timestamp with time zone)',
    'fn_admin_os_resolve_ticket(uuid,text,text)','fn_admin_os_resolve_report(uuid,text)',
    'fn_admin_os_log_communication(text,text,text,text,jsonb)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon',fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated',fn);
  END LOOP;
END $$;

COMMENT ON TABLE public.admin_driver_restrictions IS 'Auditable, reversible source of truth for Admin-imposed driver access restrictions.';
COMMENT ON FUNCTION public.fn_admin_os_overview() IS 'Privacy-safe operational aggregate for the HeyCaby Admin OS.';
COMMENT ON FUNCTION public.fn_admin_os_set_driver_restriction(uuid,boolean,text,timestamptz) IS 'Canonical MFA-gated driver restriction command with exact state rollback and audit.';
