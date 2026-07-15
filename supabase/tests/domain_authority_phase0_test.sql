-- Run against a database with domain_authority_phase0_containment applied.
-- The transaction is always rolled back; no test event persists.

BEGIN;

DO $verify$
DECLARE
  v_result jsonb;
  v_definition text;
BEGIN
  IF has_function_privilege(
    'anon', 'public.delete_all_auth_users()', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon can execute delete_all_auth_users';
  END IF;

  IF has_function_privilege(
    'authenticated', 'public.delete_all_auth_users()', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated can execute delete_all_auth_users';
  END IF;

  IF has_function_privilege(
    'anon', 'public.offer_ride_swap(uuid,uuid,text,text)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon can execute offer_ride_swap';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.offer_ride_swap(uuid,uuid,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated swap compatibility wrapper missing';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'private.offer_ride_swap(uuid,uuid,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated can bypass swap wrapper';
  END IF;

  IF has_function_privilege(
    'authenticated', 'public.fn_confirm_swap_ride(uuid,text)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'unsafe community confirmation remains public';
  END IF;

  IF has_table_privilege(
    'authenticated', 'public.driver_notify_queue', 'INSERT'
  ) OR has_table_privilege(
    'authenticated', 'public.driver_notify_queue', 'SELECT'
  ) THEN
    RAISE EXCEPTION 'driver_notify_queue remains client accessible';
  END IF;

  IF has_table_privilege(
    'authenticated', 'public.notifications', 'INSERT'
  ) OR has_table_privilege(
    'authenticated', 'public.notifications', 'UPDATE'
  ) THEN
    RAISE EXCEPTION 'notification intent remains client writable';
  END IF;

  IF has_column_privilege(
    'authenticated', 'public.messages', 'content', 'UPDATE'
  ) THEN
    RAISE EXCEPTION 'message content remains mutable';
  END IF;

  IF NOT has_column_privilege(
    'authenticated', 'public.messages', 'is_read', 'UPDATE'
  ) THEN
    RAISE EXCEPTION 'message acknowledgement compatibility missing';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.fn_rider_accept_marketplace_offer(uuid,uuid)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.fn_rider_accept_marketplace_offer(uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'marketplace command grants invalid';
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_admin_set_manual_verifications(uuid,boolean,boolean,boolean,boolean)'::regprocedure
  )
  INTO v_definition;

  IF v_definition ILIKE '%raw_user_meta_data%' THEN
    RAISE EXCEPTION 'admin function trusts user metadata';
  END IF;

  IF v_definition NOT ILIKE '%kvk_verified = COALESCE(p_kvk_verified%' THEN
    RAISE EXCEPTION 'admin KVK assignment is not fixed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = 'public.drivers'::regclass
      AND tgname = 'guard_driver_authority_columns'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'driver authority trigger missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = 'public.ride_requests'::regclass
      AND tgname = 'guard_ride_authority_columns'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'ride authority trigger missing';
  END IF;

  v_result := public.offer_ride_swap(
    gen_random_uuid(), gen_random_uuid(), 'other', NULL
  );
  IF v_result->>'error' <> 'not_authorized' THEN
    RAISE EXCEPTION 'swap wrapper did not fail closed: %', v_result;
  END IF;

  v_result := public.fn_rider_accept_marketplace_offer(
    gen_random_uuid(), gen_random_uuid()
  );
  IF v_result->>'code' <> 'not_authorized' THEN
    RAISE EXCEPTION 'marketplace command did not fail closed: %', v_result;
  END IF;
END;
$verify$;

SELECT 'domain_authority_phase0_passed' AS result;

ROLLBACK;
