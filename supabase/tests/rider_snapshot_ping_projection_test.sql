-- Run after rider_snapshot_ping_projection in a disposable database.
BEGIN;

DO $verify$
DECLARE
  v_result jsonb;
  v_definition text;
BEGIN
  v_result := public.fn_rider_ride_snapshot(
    '00000000-0000-0000-0000-000000000071',
    NULL
  );
  IF v_result ->> 'booking_mode' IS DISTINCT FROM 'instant'
     OR (v_result ->> 'driver_on_my_way')::boolean IS NOT TRUE
     OR (v_result ->> 'driver_on_my_way_at')::timestamptz IS DISTINCT FROM
        '2026-07-14T07:01:02Z'::timestamptz THEN
    RAISE EXCEPTION 'latest on-my-way projection is incorrect: %', v_result;
  END IF;

  v_result := public.fn_rider_ride_snapshot(
    '00000000-0000-0000-0000-000000000072',
    NULL
  );
  IF v_result ->> 'booking_mode' IS DISTINCT FROM 'terug'
     OR (v_result ->> 'driver_on_my_way')::boolean IS NOT FALSE
     OR v_result ->> 'driver_on_my_way_at' IS NOT NULL THEN
    RAISE EXCEPTION 'no-ping projection is incorrect: %', v_result;
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_rider_ride_snapshot(uuid,text)'::regprocedure
  ) INTO v_definition;
  IF v_definition NOT ILIKE '%private.fn_rider_ride_snapshot_base%'
     OR v_definition NOT ILIKE '%driver.ping_on_my_way.%'
     OR v_definition NOT ILIKE '%driver.ping_nearby.%'
     OR v_definition NOT ILIKE '%max(ral.occurred_at)%' THEN
    RAISE EXCEPTION 'snapshot wrapper duplicates or omits ping authority';
  END IF;

  IF NOT has_function_privilege(
    'anon', 'public.fn_rider_ride_snapshot(uuid,text)', 'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated', 'public.fn_rider_ride_snapshot(uuid,text)', 'EXECUTE'
  ) OR NOT has_function_privilege(
    'service_role', 'public.fn_rider_ride_snapshot(uuid,text)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'released snapshot grants changed';
  END IF;

  IF has_function_privilege(
    'anon', 'private.fn_rider_ride_snapshot_base(uuid,text)', 'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'private.fn_rider_ride_snapshot_base(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'private snapshot base is exposed';
  END IF;
END;
$verify$;

SELECT 'rider_snapshot_ping_projection_passed' AS result;

ROLLBACK;
