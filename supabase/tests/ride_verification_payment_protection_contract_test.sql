BEGIN;

DO $verify$
DECLARE
  v_flags jsonb;
  v_gate text;
  v_transition text;
BEGIN
  SELECT value::jsonb INTO v_flags FROM public.app_config WHERE key='feature_flags';
  IF COALESCE((v_flags->>'ride_arrival_verification_enabled')::boolean,true)
     OR COALESCE((v_flags->>'pickup_locking_enabled')::boolean,true)
     OR COALESCE((v_flags->>'boarding_pin_enabled')::boolean,true)
     OR COALESCE((v_flags->>'route_evidence_enabled')::boolean,true)
     OR COALESCE((v_flags->>'verified_completion_enabled')::boolean,true)
     OR COALESCE((v_flags->>'payment_evidence_gate_enabled')::boolean,true) THEN
    RAISE EXCEPTION 'ride verification flags must install disabled';
  END IF;

  IF to_regclass('public.ride_verification_state') IS NULL
     OR to_regclass('public.ride_pickup_versions') IS NULL
     OR to_regclass('public.ride_protection_cases') IS NULL THEN
    RAISE EXCEPTION 'ride verification evidence tables are missing';
  END IF;

  IF has_function_privilege('authenticated','public.fn_ride_payment_evidence_gate(uuid)','EXECUTE')
     OR has_function_privilege('anon','public.fn_ride_payment_evidence_gate(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'payment evidence gate is callable by an app role';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema='public'
      AND table_name IN ('ride_verification_state','ride_boarding_secrets','ride_pickup_versions','ride_contact_attempts','ride_protection_cases')
      AND grantee IN ('anon','authenticated')
  ) THEN
    RAISE EXCEPTION 'app roles have direct evidence table grants';
  END IF;

  SELECT pg_get_functiondef('public.fn_ride_payment_evidence_gate(uuid)'::regprocedure) INTO v_gate;
  IF v_gate NOT ILIKE '%arrival_verified%'
     OR v_gate NOT ILIKE '%boarding_verified%'
     OR v_gate NOT ILIKE '%completion_verified%'
     OR v_gate NOT ILIKE '%risk_status%'
     OR v_gate NOT ILIKE '%payment_eligible_at%' THEN
    RAISE EXCEPTION 'payment evidence gate is incomplete';
  END IF;

  SELECT pg_get_functiondef('private.trg_enforce_protected_ride_transition()'::regprocedure) INTO v_transition;
  IF v_transition NOT ILIKE '%arrival_verification_required%'
     OR v_transition NOT ILIKE '%boarding_verification_required%'
     OR v_transition NOT ILIKE '%completion_verification_required%'
     OR v_transition NOT ILIKE '%verified_ride_requires_case_review%' THEN
    RAISE EXCEPTION 'protected lifecycle transition guard is incomplete';
  END IF;
END;
$verify$;

SELECT 'ride_verification_payment_protection_contract_passed' AS result;
ROLLBACK;
