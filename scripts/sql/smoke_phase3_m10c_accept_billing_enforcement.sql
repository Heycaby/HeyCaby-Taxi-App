-- Phase 3 M10C: Full validation suite (ROLLBACK).
-- Requires M10C migration applied (enforcement + accept + flag).

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp._m10c_reset(p_driver uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.billing_ledger WHERE driver_id = p_driver AND (metadata->>'smoke_m10c') IS NOT NULL;
  DELETE FROM public.billing_audit_log WHERE driver_id = p_driver AND (metadata->>'smoke_m10c') = 'true';
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp._m10c_set_outstanding(p_driver uuid, p_cents int)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp._m10c_reset(p_driver);
  IF p_cents > 0 THEN
    INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
    VALUES (p_driver, p_cents, 'manual_adjustment', jsonb_build_object('smoke_m10c', true));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp._m10c_set_driver_jwt(p_driver uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_user uuid;
BEGIN
  SELECT user_id INTO v_user FROM public.drivers WHERE id = p_driver;
  PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
END;
$$;

-- Test 0: Feature flag off — LOCKED balance but allowed (emergency rollback path)
DO $$
DECLARE v_driver uuid; v_check jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  UPDATE public.market_config SET config_value = 'false'::jsonb
  WHERE scope = 'country' AND country_code = 'NL' AND config_key = 'billing_enforcement' AND active = true;
  PERFORM pg_temp._m10c_set_outstanding(v_driver, 6100);
  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'allowed')::boolean <> true THEN
    RAISE EXCEPTION 'Test 0 FAIL: flag off should allow, got %', v_check;
  END IF;
  UPDATE public.market_config SET config_value = 'true'::jsonb
  WHERE scope = 'country' AND country_code = 'NL' AND config_key = 'billing_enforcement' AND active = true;
  RAISE NOTICE 'PASS Test 0: billing_enforcement=false bypasses block';
END $$;

-- Test 1: Payment recovery
DO $$
DECLARE v_driver uuid; v_check jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m10c_set_outstanding(v_driver, 6100);
  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'allowed')::boolean <> false THEN RAISE EXCEPTION 'Test 1a %', v_check; END IF;
  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
  VALUES (v_driver, -6100, 'settlement', jsonb_build_object('smoke_m10c', true));
  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'allowed')::boolean <> true THEN RAISE EXCEPTION 'Test 1b %', v_check; END IF;
  RAISE NOTICE 'PASS Test 1: payment recovery';
END $$;

-- Test 2: Accept-time race + dual audit
DO $$
DECLARE v_driver uuid; v_ride uuid; v_result json; v_bc int; v_dc int;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m10c_set_outstanding(v_driver, 0);
  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('M10C T2', 'D', 'pending') RETURNING id INTO v_ride;
  INSERT INTO public.ride_request_invites (ride_request_id, driver_id, batch_no, expires_at, status)
  VALUES (v_ride, v_driver, 1, now() + interval '30 seconds', 'pending');
  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
  VALUES (v_driver, 6100, 'manual_adjustment', jsonb_build_object('smoke_m10c', true));
  PERFORM pg_temp._m10c_set_driver_jwt(v_driver);
  v_result := public.fn_driver_accept_ride_invite(v_ride)::json;
  IF (v_result->>'ok')::boolean <> false OR v_result->>'error' <> 'billing_locked' THEN
    RAISE EXCEPTION 'Test 2 accept %', v_result;
  END IF;
  SELECT COUNT(*) INTO v_bc FROM public.billing_audit_log
  WHERE driver_id = v_driver AND event = 'billing.accept_blocked' AND ride_id = v_ride;
  SELECT COUNT(*) INTO v_dc FROM public.ride_audit_log
  WHERE ride_id = v_ride AND event = 'dispatch.driver_rejected_billing';
  IF v_bc < 1 OR v_dc < 1 THEN RAISE EXCEPTION 'Test 2 audit bc=% dc=%', v_bc, v_dc; END IF;
  RAISE NOTICE 'PASS Test 2: accept-time reject';
END $$;

-- Test 3: End-to-end lifecycle — €59 → +€1 → blocked → pay → accept
DO $$
DECLARE
  v_driver uuid;
  v_ride1 uuid;
  v_ride2 uuid;
  v_result json;
  v_check jsonb;
  v_fee_ride uuid;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  PERFORM pg_temp._m10c_set_outstanding(v_driver, 5900);

  INSERT INTO public.ride_requests (pickup_address, destination_address, status, driver_id, country_code)
  VALUES ('M10C E2E Complete', 'D', 'in_progress', v_driver, 'NL')
  RETURNING id INTO v_fee_ride;

  UPDATE public.ride_requests SET status = 'completed' WHERE id = v_fee_ride;

  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'outstanding_cents')::int < 6000 THEN
    RAISE EXCEPTION 'Test 3: expected >=6000 after ride fee, got %', v_check;
  END IF;

  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('M10C E2E Block', 'D', 'pending') RETURNING id INTO v_ride1;
  INSERT INTO public.ride_request_invites (ride_request_id, driver_id, batch_no, expires_at, status)
  VALUES (v_ride1, v_driver, 1, now() + interval '30 seconds', 'pending');

  PERFORM pg_temp._m10c_set_driver_jwt(v_driver);
  v_result := public.fn_driver_accept_ride_invite(v_ride1)::json;
  IF (v_result->>'ok')::boolean <> false THEN
    RAISE EXCEPTION 'Test 3 block expected, got %', v_result;
  END IF;

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
  VALUES (v_driver, -6000, 'settlement', jsonb_build_object('smoke_m10c', 'e2e_pay'));

  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('M10C E2E Accept', 'D', 'pending') RETURNING id INTO v_ride2;
  INSERT INTO public.ride_request_invites (ride_request_id, driver_id, batch_no, expires_at, status)
  VALUES (v_ride2, v_driver, 1, now() + interval '30 seconds', 'pending');

  v_result := public.fn_driver_accept_ride_invite(v_ride2)::json;
  IF (v_result->>'ok')::boolean <> true THEN
    RAISE EXCEPTION 'Test 3 accept after pay failed: %', v_result;
  END IF;

  RAISE NOTICE 'PASS Test 3: full billing lifecycle';
END $$;

ROLLBACK;

SELECT 'M10C_SMOKE_PASSED' AS result;
