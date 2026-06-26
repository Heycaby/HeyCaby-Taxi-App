-- M14D — Connectivity observability views + platform_health extension. REPO ONLY.

CREATE OR REPLACE VIEW public.v_connectivity_active_sessions
WITH (security_invoker = true)
AS
SELECT
  s.id AS session_id,
  s.driver_id,
  s.device_id,
  s.transport_state,
  s.presence_state,
  s.operational_state,
  s.connected_at,
  s.last_heartbeat_at,
  s.last_realtime_at,
  s.state_machine_version,
  timezone('utc', now()) - s.connected_at AS session_age
FROM public.driver_sessions s
WHERE s.ended_at IS NULL AND s.is_authoritative = true;

CREATE OR REPLACE VIEW public.v_connectivity_session_duration_daily
WITH (security_invoker = true)
AS
SELECT
  date_trunc('day', s.connected_at) AS day,
  COUNT(*) AS sessions_ended,
  AVG(EXTRACT(EPOCH FROM (s.ended_at - s.connected_at))) AS avg_duration_seconds
FROM public.driver_sessions s
WHERE s.ended_at IS NOT NULL
GROUP BY 1;

CREATE OR REPLACE VIEW public.v_connectivity_legacy_drift
WITH (security_invoker = true)
AS
SELECT
  d.id AS driver_id,
  d.status::text AS legacy_status,
  s.operational_state AS session_operational,
  s.presence_state,
  s.id AS session_id
FROM public.drivers d
LEFT JOIN public.driver_sessions s
  ON s.driver_id = d.id AND s.is_authoritative = true AND s.ended_at IS NULL
WHERE d.status::text IS DISTINCT FROM s.operational_state;

CREATE OR REPLACE VIEW public.v_connectivity_event_rates
WITH (security_invoker = true)
AS
SELECT
  date_trunc('hour', e.occurred_at) AS hour,
  e.event_type,
  e.state_machine_version,
  COUNT(*) AS event_count
FROM public.driver_connectivity_events e
GROUP BY 1, 2, 3;

GRANT SELECT ON public.v_connectivity_active_sessions TO authenticated, service_role;
GRANT SELECT ON public.v_connectivity_session_duration_daily TO authenticated, service_role;
GRANT SELECT ON public.v_connectivity_legacy_drift TO authenticated, service_role;
GRANT SELECT ON public.v_connectivity_event_rates TO authenticated, service_role;

-- Extend platform_health with connectivity section (observe-only; dispatch unchanged)
CREATE OR REPLACE FUNCTION public.fn_driver_platform_health(
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_d public.drivers%ROWTYPE;
  v_billing jsonb;
  v_summary jsonb;
  v_verified boolean;
  v_docs boolean;
  v_vehicle boolean;
  v_online boolean;
  v_dispatch_eligible boolean;
  v_session public.driver_sessions%ROWTYPE;
  v_layers_aligned boolean;
BEGIN
  IF p_driver_id IS NOT NULL THEN
    IF auth.uid() IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
       AND NOT EXISTS (
         SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
       )
    THEN
      RETURN jsonb_build_object('allowed', false, 'error', 'forbidden');
    END IF;
    v_driver_id := p_driver_id;
  ELSE
    SELECT d.id INTO v_driver_id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = v_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'driver_not_found');
  END IF;

  v_billing := public.fn_driver_can_accept_rides(v_driver_id);
  v_summary := public.fn_driver_billing_summary(v_driver_id);

  v_verified := COALESCE(v_d.profile_status = 'verified', false)
    OR COALESCE(v_d.is_verified_badge, false);
  v_docs := COALESCE(v_d.chauffeurspas_verified, false)
    AND COALESCE(v_d.rijbewijs_verified, false)
    AND COALESCE(v_d.taxi_insurance_verified, false);
  v_vehicle := COALESCE(v_d.vehicle_verified, false)
    OR COALESCE(v_d.vehicle_photos_approved, false);
  v_online := v_d.status = 'available';

  v_dispatch_eligible :=
    COALESCE((v_billing->>'allowed')::boolean, false)
    AND v_online
    AND COALESCE(v_d.compliance_status, '') IS DISTINCT FROM 'suspended'
    AND COALESCE(v_d.min_profile_requirements_met, false);

  SELECT * INTO v_session
  FROM public.driver_sessions s
  WHERE s.driver_id = v_driver_id AND s.is_authoritative = true AND s.ended_at IS NULL
  ORDER BY s.created_at DESC
  LIMIT 1;

  v_layers_aligned := (
    v_session.id IS NULL
    OR v_d.status::text IS NOT DISTINCT FROM v_session.operational_state
  );

  RETURN jsonb_build_object(
    'allowed', v_dispatch_eligible,
    'billing', jsonb_build_object(
      'status', v_summary->>'status',
      'outstanding', (v_summary->>'outstanding')::bigint,
      'limit', (v_summary->>'limit')::bigint,
      'remaining', (v_summary->>'remaining')::bigint,
      'currency', v_summary->>'currency',
      'can_accept_rides', (v_billing->>'allowed')::boolean
    ),
    'driver', jsonb_build_object(
      'verified', v_verified,
      'documents_valid', v_docs,
      'vehicle_approved', v_vehicle,
      'is_online', v_online,
      'compliance_status', v_d.compliance_status,
      'profile_status', v_d.profile_status,
      'operational_status', v_d.status::text
    ),
    'connectivity', jsonb_build_object(
      'm14_enabled', public.fn_connectivity_m14_enabled(v_driver_id),
      'session_id', v_session.id,
      'transport', COALESCE(v_session.transport_state, 'disconnected'),
      'presence', COALESCE(v_session.presence_state, 'unknown'),
      'operational', COALESCE(v_session.operational_state, 'offline'),
      'last_heartbeat_at', v_session.last_heartbeat_at,
      'last_realtime_at', v_session.last_realtime_at,
      'legacy_status', v_d.status::text,
      'layers_aligned', v_layers_aligned,
      'state_machine_version', COALESCE(v_session.state_machine_version, 1)
    ),
    'dispatch', jsonb_build_object(
      'eligible', v_dispatch_eligible
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_platform_health(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_platform_health(uuid) TO authenticated, service_role;
