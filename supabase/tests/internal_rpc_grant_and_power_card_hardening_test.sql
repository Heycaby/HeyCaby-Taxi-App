DO $$
DECLARE
  v_signature text;
  v_internal text[] := ARRAY[
    'public.check_all_compliance_expiries()',
    'public.expire_stale_auctions()',
    'public.expire_stale_favorite_requests()',
    'public.expire_stale_swaps()',
    'public.fn_claim_due_rider_lifecycle_jobs(integer)',
    'public.fn_community_cleanup_expired_posts()',
    'public.fn_driver_force_offline_for_handover(uuid,text)',
    'public.fn_billing_audit_append(uuid,text,uuid,jsonb,uuid)',
    'public.fn_driver_billing_apply_settlement(uuid,integer,text,text,jsonb)',
    'public.fn_driver_billing_checkout_intent_by_payment(text)',
    'public.fn_driver_billing_record_checkout_intent(uuid,integer,text,text,text,text,text,jsonb)'
  ];
  v_definition text;
BEGIN
  FOREACH v_signature IN ARRAY v_internal LOOP
    IF has_function_privilege('anon', v_signature, 'EXECUTE')
       OR has_function_privilege('authenticated', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'backend-only function remains client executable: %',
        v_signature;
    END IF;
    IF NOT has_function_privilege('service_role', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'backend-only function lost service execution: %',
        v_signature;
    END IF;
  END LOOP;

  FOREACH v_signature IN ARRAY ARRAY[
    'public.fn_dismiss_power_card(uuid,uuid)',
    'public.fn_act_on_power_card(uuid,uuid)'
  ] LOOP
    IF has_function_privilege('anon', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'power-card command grants are not actor-safe: %',
        v_signature;
    END IF;

    SELECT pg_get_functiondef(v_signature::regprocedure)
    INTO v_definition;
    IF v_definition NOT ILIKE '%d.user_id = auth.uid()%'
       OR v_definition NOT ILIKE '%v_driver_id <> p_driver_id%' THEN
      RAISE EXCEPTION 'power-card command does not bind auth actor: %',
        v_signature;
    END IF;
  END LOOP;
END;
$$;

SELECT 'internal_rpc_grant_and_power_card_hardening_passed' AS result;
