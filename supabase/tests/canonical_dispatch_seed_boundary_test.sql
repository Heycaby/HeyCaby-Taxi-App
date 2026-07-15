BEGIN;

DO $$
DECLARE
  v_router oid := to_regprocedure(
    'public.fn_seed_ride_matching_batch(uuid,integer,integer)'
  );
  v_definition text;
  v_helper regprocedure;
BEGIN
  IF v_router IS NULL THEN
    RAISE EXCEPTION 'missing canonical dispatch router';
  END IF;

  SELECT pg_get_functiondef(v_router) INTO v_definition;

  IF v_definition NOT LIKE '%fn_seed_taxi_terug_matching_batch%'
     OR v_definition NOT LIKE '%fn_seed_ride_matching_batch_dispatch_v3%'
     OR v_definition NOT LIKE '%fn_rider_resolve_identity_id%'
     OR v_definition NOT LIKE '%ride_not_found%'
     OR v_definition NOT LIKE '%forbidden%' THEN
    RAISE EXCEPTION 'canonical dispatch router is missing routing or auth checks';
  END IF;

  IF has_function_privilege('anon', v_router, 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute canonical dispatch seeding';
  END IF;

  IF NOT has_function_privilege('authenticated', v_router, 'EXECUTE') THEN
    RAISE EXCEPTION 'released authenticated Rider clients lost dispatch seeding';
  END IF;

  FOREACH v_helper IN ARRAY ARRAY[
    'public.fn_seed_ride_matching_batch_dispatch_v3(uuid,integer,integer)'::regprocedure,
    'public.fn_seed_ride_matching_batch_legacy(uuid,integer,integer)'::regprocedure,
    'public.fn_seed_taxi_terug_matching_batch(uuid,integer,integer)'::regprocedure,
    'public.fn_advance_ride_matching_waves(integer)'::regprocedure,
    'public.fn_seed_due_scheduled_ride_matching(integer,integer,integer)'::regprocedure,
    'public.fn_accept_invite_diagnostic(uuid,uuid,integer)'::regprocedure
  ]
  LOOP
    IF has_function_privilege('anon', v_helper, 'EXECUTE')
       OR has_function_privilege('authenticated', v_helper, 'EXECUTE') THEN
      RAISE EXCEPTION 'internal dispatch helper remains client-callable: %', v_helper;
    END IF;

    IF NOT has_function_privilege('service_role', v_helper, 'EXECUTE') THEN
      RAISE EXCEPTION 'service role lost internal dispatch helper: %', v_helper;
    END IF;
  END LOOP;
END;
$$;

SELECT 'canonical_dispatch_seed_boundary_passed' AS result;

ROLLBACK;
