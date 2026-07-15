-- Run after accept_fare_snapshot_authority. Read-only contract and resolver
-- checks; no customer ride or tariff rows are changed.
BEGIN;

DO $verify$
DECLARE
  v_definition text;
  v_trigger_definition text;
  v_result jsonb;
  v_driver_id uuid;
  v_profile public.driver_rate_profiles%ROWTYPE;
  v_expected numeric;
BEGIN
  SELECT pg_get_functiondef(
    'private.fn_resolve_accept_fare_snapshot(uuid,numeric,numeric,numeric)'
      ::regprocedure
  ) INTO v_definition;

  IF v_definition NOT ILIKE '%p_existing_fare > 0%'
     OR v_definition NOT ILIKE '%rp.is_active = true%'
     OR v_definition NOT ILIKE '%rp.sort_order ASC%'
     OR v_definition NOT ILIKE '%v_profile.base_fare%'
     OR v_definition NOT ILIKE '%v_profile.per_km_rate%'
     OR v_definition NOT ILIKE '%v_profile.per_min_rate%'
     OR v_definition NOT ILIKE '%v_profile.minimum_fare%' THEN
    RAISE EXCEPTION 'accept fare resolver does not preserve released formula';
  END IF;

  IF has_function_privilege(
    'anon',
    'private.fn_resolve_accept_fare_snapshot(uuid,numeric,numeric,numeric)',
    'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'private.fn_resolve_accept_fare_snapshot(uuid,numeric,numeric,numeric)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'accept fare resolver is exposed to a client role';
  END IF;

  SELECT pg_get_triggerdef(t.oid, true)
  INTO v_trigger_definition
  FROM pg_trigger t
  WHERE t.tgrelid = 'public.ride_requests'::regclass
    AND t.tgname = 'accept_fare_snapshot_authority'
    AND NOT t.tgisinternal;

  IF v_trigger_definition IS NULL
     OR v_trigger_definition NOT ILIKE '%BEFORE UPDATE OF status, driver_id%'
     OR v_trigger_definition NOT ILIKE
       '%private.trg_snapshot_fare_on_ride_accept()%'
     OR NOT EXISTS (
       SELECT 1
       FROM pg_trigger t
       WHERE t.tgrelid = 'public.ride_requests'::regclass
         AND t.tgname = 'accept_fare_snapshot_authority'
         AND t.tgenabled <> 'D'
     ) THEN
    RAISE EXCEPTION 'accept fare snapshot trigger missing or disabled';
  END IF;

  SELECT pg_get_functiondef(
    'private.trg_snapshot_fare_on_ride_accept()'::regprocedure
  ) INTO v_definition;
  IF v_definition NOT ILIKE '%OLD.status::text IS DISTINCT FROM ''pending''%'
     OR v_definition NOT ILIKE '%NEW.status::text IS DISTINCT FROM ''accepted''%'
     OR v_definition NOT ILIKE '%NEW.offered_fare := v_fare%'
     OR v_definition NOT ILIKE '%NEW.quoted_fare := v_fare%'
     OR v_definition NOT ILIKE '%NEW.estimated_fare := v_fare%'
     OR v_definition NOT ILIKE '%pricing.accept_fare_snapshotted%'
     OR v_definition NOT ILIKE '%pricing.accept_fare_snapshot_missing%' THEN
    RAISE EXCEPTION 'accept fare trigger does not own snapshot and monitoring';
  END IF;

  v_result := private.fn_resolve_accept_fare_snapshot(
    NULL,
    42.555,
    NULL,
    NULL
  );
  IF v_result ->> 'source' IS DISTINCT FROM 'existing_snapshot'
     OR (v_result ->> 'fare')::numeric <> 42.56 THEN
    RAISE EXCEPTION 'existing fare was not preserved: %', v_result;
  END IF;

  v_result := private.fn_resolve_accept_fare_snapshot(
    NULL,
    NULL,
    NULL,
    10
  );
  IF v_result ->> 'source' IS DISTINCT FROM 'missing_distance'
     OR v_result ->> 'fare' IS NOT NULL THEN
    RAISE EXCEPTION 'missing distance was not reported: %', v_result;
  END IF;

  SELECT rp.driver_id
  INTO v_driver_id
  FROM public.driver_rate_profiles rp
  WHERE rp.is_active = true
  ORDER BY rp.driver_id, rp.sort_order, rp.updated_at DESC, rp.id
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RAISE NOTICE 'No active Driver tariff fixture; static resolver contract passed';
    RETURN;
  END IF;

  SELECT rp.*
  INTO v_profile
  FROM public.driver_rate_profiles rp
  WHERE rp.driver_id = v_driver_id
    AND rp.is_active = true
  ORDER BY rp.sort_order ASC, rp.updated_at DESC, rp.id
  LIMIT 1;

  v_expected := round(
    GREATEST(
      v_profile.minimum_fare,
      v_profile.base_fare
        + v_profile.per_km_rate * 10
        + v_profile.per_min_rate * 20
    ),
    2
  );
  v_result := private.fn_resolve_accept_fare_snapshot(
    v_driver_id,
    NULL,
    10,
    20
  );

  IF v_result ->> 'source' IS DISTINCT FROM 'driver_tariff'
     OR (v_result ->> 'fare')::numeric <> v_expected
     OR (v_result ->> 'rate_profile_id')::uuid <> v_profile.id THEN
    RAISE EXCEPTION 'Driver tariff snapshot differs from released formula: %',
      v_result;
  END IF;
END;
$verify$;

SELECT 'accept_fare_snapshot_authority_passed' AS result;

ROLLBACK;
