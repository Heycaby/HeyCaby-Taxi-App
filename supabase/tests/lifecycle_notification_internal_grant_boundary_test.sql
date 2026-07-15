DO $$
DECLARE
  v_signature text;
  v_client text[] := ARRAY[
    'public.fn_driver_decline_ride_invite(uuid)',
    'public.fn_driver_ride_cancel(uuid,text)',
    'public.fn_driver_ride_en_route(uuid)',
    'public.fn_driver_ride_no_show(uuid)',
    'public.fn_app_notifications_list(text,boolean,integer,uuid,integer)',
    'public.fn_app_notification_mark_read(uuid)',
    'public.fn_app_notifications_mark_all_read(text,uuid)',
    'public.fn_app_notifications_clear_read(text,uuid)',
    'public.fn_app_notifications_delete_all(text,uuid)',
    'public.fn_app_notifications_delete_ids(uuid[],text,uuid)'
  ];
  v_internal text[] := ARRAY[
    'public.fn_app_notification_owner_ids(text,uuid)',
    'public.fn_driver_ride_lifecycle_resolve_driver()',
    'public.fn_driver_ride_lifecycle_audit(uuid,text,uuid,jsonb)',
    'public.fn_maybe_notify_near_pickup_for_driver(uuid)',
    'public.fn_process_scheduled_rides_no_driver()',
    'public.fn_recalculate_ride_fare(uuid)',
    'public.simulate_driver_movement()',
    'public.fn_driver_shift_handover_notify_fleet_owner(uuid,text,text,jsonb)',
    'public.fn_driver_shift_handover_notify_private_owner_attempt(uuid,uuid,text)'
  ];
BEGIN
  FOREACH v_signature IN ARRAY v_client LOOP
    IF has_function_privilege('anon', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'client command grant mismatch: %', v_signature;
    END IF;
  END LOOP;

  FOREACH v_signature IN ARRAY v_internal LOOP
    IF has_function_privilege('anon', v_signature, 'EXECUTE')
       OR has_function_privilege('authenticated', v_signature, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'internal helper grant mismatch: %', v_signature;
    END IF;
  END LOOP;
END;
$$;

SELECT 'lifecycle_notification_internal_grant_boundary_passed' AS result;
