BEGIN;

DO $verify$
DECLARE v_definition text; v_flags jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='driver_service_fee_versions')
    OR NOT EXISTS (SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='ride_driver_fee_snapshots') THEN
    RAISE EXCEPTION 'versioned fee configuration or ride snapshot missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.driver_service_fee_versions
    WHERE fee_code='HEYCABY_DRIVER_SERVICE_FEE' AND fee_type='fixed'
      AND amount_cents=195 AND currency='EUR') THEN
    RAISE EXCEPTION 'initial EUR 1.95 Driver Service Fee missing';
  END IF;

  SELECT NULLIF(value,'')::jsonb INTO v_flags FROM public.app_config WHERE key='feature_flags';
  IF COALESCE((v_flags->>'driver_service_fee_enabled')::boolean,true)
     OR COALESCE((v_flags->>'prepaid_driver_fee_deduction_enabled')::boolean,true)
     OR COALESCE((v_flags->>'direct_payment_driver_balance_enabled')::boolean,true)
     OR COALESCE((v_flags->>'driver_balance_restriction_enabled')::boolean,true) THEN
    RAISE EXCEPTION 'new fee branch must deploy dark';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_index
    WHERE indrelid='public.billing_ledger'::regclass AND indisunique
      AND pg_get_indexdef(indexrelid) ILIKE '%prepaid_fee_collection%') THEN
    RAISE EXCEPTION 'prepaid collection idempotency index missing';
  END IF;

  SELECT pg_get_functiondef('public.fn_finalize_completed_ride_fee(uuid)'::regprocedure)
    INTO v_definition;
  IF v_definition NOT ILIKE '%ride_not_completed%'
     OR v_definition NOT ILIKE '%driver_platform_balance%'
     OR v_definition NOT ILIKE '%mollie_deduction%'
     OR v_definition NOT ILIKE '%ON CONFLICT%' THEN
    RAISE EXCEPTION 'completed-ride fee finalization lacks state, collection, or idempotency guard';
  END IF;

  SELECT pg_get_functiondef('public.fn_check_driver_payment_eligibility(uuid,uuid)'::regprocedure)
    INTO v_definition;
  IF v_definition NOT ILIKE '%direct_payment_ride_allowed%'
     OR v_definition NOT ILIKE '%prepaid_ride_allowed%'
     OR v_definition NOT ILIKE '%driver_platform_balance_limit_reached%' THEN
    RAISE EXCEPTION 'ride-specific direct/prepaid eligibility contract missing';
  END IF;

  SELECT pg_get_functiondef('public.fn_admin_schedule_driver_service_fee_change(text,integer,integer,timestamp with time zone,text,integer,integer)'::regprocedure)
    INTO v_definition;
  IF v_definition NOT ILIKE '%fn_admin_os_actor%'
     OR v_definition NOT ILIKE '%finance.manage%'
     OR v_definition NOT ILIKE '%true%'
     OR v_definition NOT ILIKE '%fn_admin_os_audit%' THEN
    RAISE EXCEPTION 'Admin fee scheduling is missing permission, AAL2, or audit controls';
  END IF;

  IF has_function_privilege('authenticated','public.fn_finalize_completed_ride_fee(uuid)','execute')
     OR has_function_privilege('authenticated','public.fn_collect_prepaid_driver_service_fee(uuid,uuid)','execute') THEN
    RAISE EXCEPTION 'financial finalization commands are client-callable';
  END IF;
END;
$verify$;

SELECT 'driver_service_fee_platform_balance_contract_passed' AS result;
ROLLBACK;
