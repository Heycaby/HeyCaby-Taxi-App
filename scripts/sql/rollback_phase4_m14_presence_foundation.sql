-- Rollback M14A–M14D (connectivity foundation). Apply in order after prod incident approval.

DROP VIEW IF EXISTS public.v_connectivity_event_rates;
DROP VIEW IF EXISTS public.v_connectivity_legacy_drift;
DROP VIEW IF EXISTS public.v_connectivity_session_duration_daily;
DROP VIEW IF EXISTS public.v_connectivity_active_sessions;

-- Restore platform_health without connectivity section (M10A version)
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
    SELECT d.id INTO v_driver_id FROM public.drivers d WHERE d.user_id = auth.uid() LIMIT 1;
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
  v_verified := COALESCE(v_d.profile_status = 'verified', false) OR COALESCE(v_d.is_verified_badge, false);
  v_docs := COALESCE(v_d.chauffeurspas_verified, false) AND COALESCE(v_d.rijbewijs_verified, false) AND COALESCE(v_d.taxi_insurance_verified, false);
  v_vehicle := COALESCE(v_d.vehicle_verified, false) OR COALESCE(v_d.vehicle_photos_approved, false);
  v_online := v_d.status = 'available';
  v_dispatch_eligible := COALESCE((v_billing->>'allowed')::boolean, false) AND v_online
    AND COALESCE(v_d.compliance_status, '') IS DISTINCT FROM 'suspended'
    AND COALESCE(v_d.min_profile_requirements_met, false);
  RETURN jsonb_build_object(
    'allowed', v_dispatch_eligible,
    'billing', jsonb_build_object(
      'status', v_summary->>'status', 'outstanding', (v_summary->>'outstanding')::bigint,
      'limit', (v_summary->>'limit')::bigint, 'remaining', (v_summary->>'remaining')::bigint,
      'currency', v_summary->>'currency', 'can_accept_rides', (v_billing->>'allowed')::boolean
    ),
    'driver', jsonb_build_object(
      'verified', v_verified, 'documents_valid', v_docs, 'vehicle_approved', v_vehicle,
      'is_online', v_online, 'compliance_status', v_d.compliance_status,
      'profile_status', v_d.profile_status, 'operational_status', v_d.status
    ),
    'dispatch', jsonb_build_object('eligible', v_dispatch_eligible)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.fn_driver_connectivity_transition(jsonb);
DROP FUNCTION IF EXISTS public.fn_driver_session_current(uuid);
DROP FUNCTION IF EXISTS public.fn_driver_connectivity_summary(uuid);
DROP FUNCTION IF EXISTS public.fn_connectivity_m14_enabled(uuid);
DROP FUNCTION IF EXISTS public.fn_connectivity_operational_target(text, text);
DROP FUNCTION IF EXISTS public.fn_connectivity_transport_target(text, text);

DROP TABLE IF EXISTS public.driver_connectivity_events;
DROP TABLE IF EXISTS public.driver_sessions;

UPDATE public.market_config SET active = false
WHERE config_key IN ('connectivity_m14_enabled', 'connectivity_state_machine_version')
  AND scope = 'country' AND country_code = 'NL';
