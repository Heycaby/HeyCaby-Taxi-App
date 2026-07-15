DO $$
DECLARE
  v_signature text;
  v_wrappers text[] := ARRAY[
    'public.get_or_create_driver(uuid)',
    'public.save_driver_profile(uuid,text,text,text,text,text)',
    'public.save_driver_preferences(uuid,integer,text[],boolean,numeric,boolean,boolean,boolean,boolean,boolean)',
    'public.save_vehicle_info(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text,text,text,text,text,text,boolean,boolean,boolean,boolean)',
    'public.verify_vehicle_and_unlock(uuid,text)',
    'public.mark_welcome_modal_seen(uuid,boolean)',
    'public.update_profile_completion(uuid,text)',
    'public.upsert_push_token(uuid,text,text)',
    'public.refresh_driver_badge(uuid)'
  ];
  v_internal text[] := ARRAY[
    'public.setup_review_driver_profile(uuid)',
    'public.mark_idle_drivers_offline()',
    'public.recompute_driver_compliance(uuid)',
    'public.recalculate_driver_rating(uuid)',
    'public.recalculate_rider_credibility(text)',
    'public.fn_ride_audit_append(uuid,text,uuid,jsonb,text,text,uuid)',
    'public.fn_driver_ride_lifecycle_mark_on_ride(uuid)',
    'public.fn_driver_ride_lifecycle_release_driver(uuid)',
    'public.fn_driver_shift_handover_consume_step_up(uuid,uuid)',
    'public.fn_driver_shift_handover_finalize(uuid,text,text)',
    'public.fn_driver_shift_handover_notify(uuid,text,text,text,jsonb)',
    'public.fn_driver_shift_handover_notify_ops(text,text,jsonb)',
    'public.fn_driver_shift_handover_queue_email(uuid,text,text,jsonb)',
    'public.fn_ensure_driver_business_account(uuid)',
    'public.fn_ensure_ride_rider_identity_for_notify(uuid)',
    'public.fn_generate_power_cards(uuid)',
    'public.fn_soft_reserve_ride(uuid,uuid)',
    'public.fn_start_radar_session(uuid,uuid)'
  ];
  v_definition text;
BEGIN
  FOREACH v_signature IN ARRAY v_wrappers LOOP
    IF has_function_privilege('anon', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'Driver profile wrapper grant mismatch: %', v_signature;
    END IF;
    SELECT pg_get_functiondef(v_signature::regprocedure) INTO v_definition;
    IF v_definition NOT ILIKE '%fn_driver_user_actor_authorized%'
       OR v_definition NOT ILIKE '%private.%' THEN
      RAISE EXCEPTION 'Driver profile wrapper lacks canonical actor boundary: %',
        v_signature;
    END IF;
  END LOOP;

  FOREACH v_signature IN ARRAY v_internal LOOP
    IF has_function_privilege('anon', v_signature, 'EXECUTE')
       OR has_function_privilege('authenticated', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'Internal helper grant mismatch: %', v_signature;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = 'save_driver_profile'
  ) THEN
    RAISE EXCEPTION 'Original Driver profile implementation was not retained';
  END IF;
END;
$$;

SELECT 'driver_profile_actor_and_internal_helper_boundary_passed' AS result;
