-- M14 smoke suite (ROLLBACK). Requires M14A–M14D migrations applied.
-- Does not touch dispatch/billing/accept.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp._m14_set_driver_jwt(p_driver uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_user uuid;
BEGIN
  SELECT user_id INTO v_user FROM public.drivers WHERE id = p_driver;
  PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp._m14_cleanup(p_driver uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.driver_connectivity_events WHERE driver_id = p_driver;
  DELETE FROM public.driver_sessions WHERE driver_id = p_driver;
END;
$$;

-- Enable M14 for smoke (rolled back)
UPDATE public.market_config SET config_value = 'true'::jsonb
WHERE scope = 'country' AND country_code = 'NL'
  AND config_key = 'connectivity_m14_enabled' AND active = true;

DO $$
DECLARE
  v_driver uuid;
  v_result jsonb;
  v_event_id uuid := gen_random_uuid();
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m14_cleanup(v_driver);
  PERFORM pg_temp._m14_set_driver_jwt(v_driver);

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_id', v_event_id,
    'event_version', 1,
    'state_machine_version', 1,
    'event_type', 'connectivity.session.start',
    'device_id', 'smoke-m14-device',
    'metadata', jsonb_build_object('platform', 'ios', 'app_version', 'smoke')
  ));

  IF (v_result->>'ok')::boolean <> true THEN
    RAISE EXCEPTION 'Test 1 session.start failed: %', v_result;
  END IF;
  IF (v_result->'states'->>'presence') <> 'present' THEN
    RAISE EXCEPTION 'Test 1 presence: %', v_result;
  END IF;

  RAISE NOTICE 'PASS Test 1: session.start';
END $$;

DO $$
DECLARE v_driver uuid; v_result jsonb; v_sid uuid;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m14_set_driver_jwt(v_driver);
  SELECT (public.fn_driver_session_current(v_driver)->>'session_id')::uuid INTO v_sid;

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_type', 'connectivity.operational.go_available',
    'session_id', v_sid
  ));
  IF (v_result->>'ok')::boolean <> true OR (v_result->'states'->>'operational') <> 'available' THEN
    RAISE EXCEPTION 'Test 2 go_available: %', v_result;
  END IF;

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_type', 'connectivity.operational.go_offline',
    'session_id', v_sid
  ));
  IF (v_result->'states'->>'operational') <> 'offline' THEN
    RAISE EXCEPTION 'Test 2 go_offline: %', v_result;
  END IF;

  RAISE NOTICE 'PASS Test 2: operational transitions';
END $$;

DO $$
DECLARE v_driver uuid; v_result jsonb; v_sid uuid;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m14_set_driver_jwt(v_driver);
  SELECT (public.fn_driver_session_current(v_driver)->>'session_id')::uuid INTO v_sid;

  PERFORM public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_type', 'connectivity.operational.go_available', 'session_id', v_sid));
  PERFORM public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_type', 'connectivity.operational.ride_accepted', 'session_id', v_sid));

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_type', 'connectivity.operational.go_offline', 'session_id', v_sid));

  IF (v_result->>'ok')::boolean <> false OR v_result->>'error' <> 'illegal_transition' THEN
    RAISE EXCEPTION 'Test 3 expected illegal: %', v_result;
  END IF;

  RAISE NOTICE 'PASS Test 3: illegal busy→offline rejected';
END $$;

DO $$
DECLARE v_driver uuid; v_result jsonb; v_sid uuid; v_eid uuid := gen_random_uuid();
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m14_set_driver_jwt(v_driver);
  SELECT (public.fn_driver_session_current(v_driver)->>'session_id')::uuid INTO v_sid;

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_id', v_eid,
    'event_type', 'connectivity.session.end',
    'session_id', v_sid,
    'metadata', jsonb_build_object('reason', 'smoke')
  ));
  IF (v_result->>'ok')::boolean <> true THEN RAISE EXCEPTION 'Test 4 end: %', v_result; END IF;

  SELECT COUNT(*) INTO v_sid FROM public.driver_sessions
  WHERE driver_id = v_driver AND ended_at IS NOT NULL;
  IF v_sid < 1 THEN RAISE EXCEPTION 'Test 4 session not ended'; END IF;

  RAISE NOTICE 'PASS Test 4: session.end';
END $$;

DO $$
DECLARE v_driver uuid; v_health jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m14_cleanup(v_driver);
  PERFORM pg_temp._m14_set_driver_jwt(v_driver);

  PERFORM public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_type', 'connectivity.session.start', 'device_id', 'health-smoke'));

  v_health := public.fn_driver_platform_health(v_driver);
  IF v_health->'connectivity' IS NULL THEN
    RAISE EXCEPTION 'Test 5 missing connectivity section';
  END IF;

  RAISE NOTICE 'PASS Test 5: platform_health connectivity';
END $$;

DO $$
DECLARE v_driver uuid; v_result jsonb; v_eid uuid := gen_random_uuid(); v_n int;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m14_cleanup(v_driver);
  PERFORM pg_temp._m14_set_driver_jwt(v_driver);

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_id', v_eid,
    'event_type', 'connectivity.session.start',
    'device_id', 'dedup-smoke'));

  v_result := public.fn_driver_connectivity_transition(jsonb_build_object(
    'event_id', v_eid,
    'event_type', 'connectivity.operational.go_available'));

  IF (v_result->>'deduplicated')::boolean <> true THEN
    RAISE EXCEPTION 'Test 6 dedup: %', v_result;
  END IF;

  SELECT COUNT(*) INTO v_n FROM public.driver_connectivity_events WHERE event_id = v_eid;
  IF v_n <> 1 THEN RAISE EXCEPTION 'Test 6 event count %', v_n; END IF;

  RAISE NOTICE 'PASS Test 6: event_id deduplication';
END $$;

ROLLBACK;

SELECT 'M14_SMOKE_PASSED' AS result;
