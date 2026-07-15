-- Run after taxi_terug_offer_boost_realtime_delivery. All functional writes
-- are rolled back, including the pg_net queue entry.
BEGIN;

DO $verify$
DECLARE
  v_definition text;
BEGIN
  IF has_function_privilege(
    'anon',
    'public.fn_rider_boost_marketplace_offer(uuid,numeric)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.fn_rider_boost_marketplace_offer(uuid,numeric)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Taxi Terug boost compatibility grants invalid';
  END IF;

  IF has_function_privilege(
    'anon',
    'private.fn_driver_agent_enqueue_event(jsonb)',
    'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'private.fn_driver_agent_enqueue_event(jsonb)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'service_role',
    'private.fn_driver_agent_enqueue_event(jsonb)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'driver-agent enqueue boundary grants invalid';
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_rider_boost_marketplace_offer(uuid,numeric)'::regprocedure
  ) INTO v_definition;

  IF v_definition NOT ILIKE '%FOR UPDATE%'
     OR v_definition NOT ILIKE '%fare_not_increased%'
     OR v_definition NOT ILIKE '%taxi_terug.offer_increased%'
     OR v_definition NOT ILIKE '%fn_driver_agent_enqueue_event%'
     OR v_definition NOT ILIKE '%private.rider_owns_ride%' THEN
    RAISE EXCEPTION 'Taxi Terug boost authority contract incomplete';
  END IF;

  SELECT pg_get_functiondef(
    'public.notify_driver_agent_trigger()'::regprocedure
  ) INTO v_definition;
  IF v_definition NOT ILIKE '%private.fn_driver_agent_enqueue_event%'
     OR v_definition ILIKE '%vault.decrypted_secrets%'
     OR v_definition ILIKE '%net.http_post%' THEN
    RAISE EXCEPTION 'database webhook transport remains duplicated';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indexrelid =
      to_regclass('public.notifications_taxi_terug_event_driver_uidx')
      AND i.indisunique
  ) THEN
    RAISE EXCEPTION 'Taxi Terug delivery idempotency index missing';
  END IF;
END;
$verify$;

DO $functional$
DECLARE
  v_ride_id uuid;
  v_user_id uuid;
  v_result jsonb;
  v_old_fare numeric := 50;
  v_new_fare numeric := 60;
  v_audit_count integer;
BEGIN
  SELECT rr.id, ri.user_id
  INTO v_ride_id, v_user_id
  FROM public.ride_requests rr
  JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
  WHERE rr.booking_mode::text = 'terug'
    AND ri.user_id IS NOT NULL
  ORDER BY rr.created_at DESC
  LIMIT 1
  FOR UPDATE OF rr;

  IF v_ride_id IS NULL THEN
    RAISE NOTICE 'Taxi Terug functional fixture unavailable; static contract passed';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_user_id, 'role', 'authenticated')::text,
    true
  );

  UPDATE public.ride_requests
  SET status = 'pending',
      driver_id = NULL,
      expires_at = now() + interval '10 minutes',
      marketplace_offered_fare = v_old_fare,
      offered_fare = v_old_fare,
      quoted_fare = v_old_fare,
      estimated_fare = v_old_fare
  WHERE id = v_ride_id;

  v_result := public.fn_rider_boost_marketplace_offer(v_ride_id, v_new_fare);
  IF v_result ->> 'ok' IS DISTINCT FROM 'true'
     OR v_result ->> 'booking_mode' IS DISTINCT FROM 'terug'
     OR (v_result ->> 'previous_fare')::numeric <> v_old_fare
     OR (v_result ->> 'new_fare')::numeric <> v_new_fare
     OR (v_result ->> 'increase')::numeric <> v_new_fare - v_old_fare THEN
    RAISE EXCEPTION 'Taxi Terug boost returned invalid backend truth: %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = v_ride_id
      AND rr.marketplace_offered_fare = v_new_fare
      AND rr.offered_fare = v_new_fare
      AND rr.quoted_fare = v_new_fare
      AND rr.estimated_fare = v_new_fare
  ) THEN
    RAISE EXCEPTION 'Taxi Terug fare snapshot was not updated atomically';
  END IF;

  SELECT count(*)
  INTO v_audit_count
  FROM public.ride_audit_log ral
  WHERE ral.ride_request_id = v_ride_id
    AND ral.event_type = 'taxi_terug.offer_increased'
    AND ral.metadata ->> 'source_event_id' = v_result ->> 'source_event_id';
  IF v_audit_count <> 1 THEN
    RAISE EXCEPTION 'Taxi Terug boost audit event missing or duplicated';
  END IF;

  v_result := public.fn_rider_boost_marketplace_offer(v_ride_id, v_new_fare);
  IF v_result ->> 'code' IS DISTINCT FROM 'fare_not_increased' THEN
    RAISE EXCEPTION 'same/lower Taxi Terug fare was accepted: %', v_result;
  END IF;

  UPDATE public.ride_requests SET status = 'cancelled' WHERE id = v_ride_id;
  v_result := public.fn_rider_boost_marketplace_offer(v_ride_id, 70);
  IF v_result ->> 'code' IS DISTINCT FROM 'ride_not_boostable' THEN
    RAISE EXCEPTION 'terminal Taxi Terug ride accepted a boost: %', v_result;
  END IF;
END;
$functional$;

SELECT 'taxi_terug_offer_boost_passed' AS result;

ROLLBACK;
