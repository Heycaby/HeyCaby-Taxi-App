-- Read-only Admin contract assertions. Compatibility grants are deliberately
-- retained until the minimum-version and legacy-retirement decisions land.
BEGIN;

DO $verify$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.fn_admin_shift_handover_allowlist_set(uuid,uuid,boolean)'::regprocedure
  ) INTO v_definition;

  IF v_definition NOT ILIKE '%fn_shift_handover_fleet_can_manage_vehicle%'
     OR v_definition NOT ILIKE '%private.domain_security_events%'
     OR v_definition NOT ILIKE '%shift_handover_allowlist_denied%'
     OR v_definition NOT ILIKE '%shift_handover_allowlist_changed%'
     OR v_definition NOT ILIKE '%before_present%'
     OR v_definition NOT ILIKE '%after_present%'
     OR v_definition NOT ILIKE '%correlation_id%' THEN
    RAISE EXCEPTION 'Admin Shift Handover mutation lacks auth/audit contract';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.fn_admin_set_manual_verifications(uuid,boolean,boolean,boolean,boolean)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.fn_admin_set_manual_verifications(uuid,boolean,boolean,boolean,boolean)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Driver readiness Admin grants invalid';
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_admin_set_manual_verifications(uuid,boolean,boolean,boolean,boolean)'::regprocedure
  ) INTO v_definition;
  IF v_definition NOT ILIKE '%raw_app_meta_data%'
     OR v_definition NOT ILIKE '%admin_verification_denied%'
     OR v_definition NOT ILIKE '%admin_verification_changed%'
     OR v_definition NOT ILIKE '%before%'
     OR v_definition NOT ILIKE '%after%' THEN
    RAISE EXCEPTION 'Driver readiness Admin command lacks role/audit contract';
  END IF;
END;
$verify$;

SELECT 'admin_domain_contract_passed' AS result;

ROLLBACK;
