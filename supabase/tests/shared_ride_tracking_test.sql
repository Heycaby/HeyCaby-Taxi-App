-- Run after shared_ride_tracking_reliability. This transaction is read-only.
BEGIN;

DO $verify$
DECLARE
  v_definition text;
  v_policy_qual text;
BEGIN
  IF has_function_privilege(
    'anon',
    'public.fn_rider_create_share_token(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon can create shared-ride capability tokens';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.fn_rider_create_share_token(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated rider share RPC grant missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = 'public.ride_shares'::regclass
      AND i.indisunique
      AND pg_get_indexdef(i.indexrelid) ILIKE '%(ride_request_id)%'
      AND pg_get_expr(i.indpred, i.indrelid) ILIKE '%is_active%'
  ) THEN
    RAISE EXCEPTION 'single active shared-ride token index missing';
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_rider_create_share_token(uuid,text)'::regprocedure
  ) INTO v_definition;

  IF v_definition ILIKE '%v_ride.rider_token = btrim(p_rider_token)%'
     OR v_definition NOT ILIKE '%FOR UPDATE%'
     OR v_definition NOT ILIKE '%expires_at > now()%'
     OR v_definition NOT ILIKE '%ride.share_created%' THEN
    RAISE EXCEPTION 'shared-ride RPC authority, locking, expiry, or audit contract invalid';
  END IF;

  SELECT qual INTO v_policy_qual
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'ride_shares'
    AND policyname = 'ride_shares_select_participant';

  IF v_policy_qual IS NULL
     OR v_policy_qual NOT ILIKE '%SELECT auth.uid()%' THEN
    RAISE EXCEPTION 'ride_shares participant policy does not use initplan auth.uid';
  END IF;
END;
$verify$;

SELECT 'shared_ride_tracking_passed' AS result;

ROLLBACK;
