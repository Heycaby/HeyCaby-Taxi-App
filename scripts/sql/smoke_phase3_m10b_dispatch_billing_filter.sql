-- Phase 3 M10B: Dispatch simulation + skip metrics validation (ROLLBACK).
-- Requires M10A live + M10B migration applied.
-- Simulates CTO table: €0/€20/€59 invite · €60/€75 no invite · closest locked skips to next eligible.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp._m10b_set_outstanding(p_driver uuid, p_cents int)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.billing_ledger WHERE driver_id = p_driver AND (metadata->>'smoke_m10b') = 'true';
  IF p_cents > 0 THEN
    INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
    VALUES (p_driver, p_cents, 'manual_adjustment', jsonb_build_object('smoke_m10b', true));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp._m10b_ensure_location(p_driver uuid, p_lat float8, p_lon float8)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_user uuid;
BEGIN
  SELECT user_id INTO v_user FROM public.drivers WHERE id = p_driver;
  IF v_user IS NULL THEN RETURN; END IF;
  UPDATE public.driver_locations
  SET latitude = p_lat, longitude = p_lon, updated_at = now(), driver_id = p_driver
  WHERE user_id = v_user;
  IF NOT FOUND THEN
    INSERT INTO public.driver_locations (user_id, driver_id, latitude, longitude, updated_at, country_code)
    VALUES (v_user, p_driver, p_lat, p_lon, now(), 'NL');
  END IF;
  UPDATE public.drivers SET status = 'available' WHERE id = p_driver;
END;
$$;

-- Test 1: Per-driver billing gate (invite vs no invite)
DO $$
DECLARE
  v_drivers uuid[];
  v_ride uuid;
  v_pickup_lat float8 := 51.9225;
  v_pickup_lon float8 := 4.47917;
  v_result json;
  v_invited uuid[];
  v_cents int[] := ARRAY[0, 2000, 5900, 6000, 7500];
  i int;
  v_expected_invite boolean;
BEGIN
  SELECT array_agg(id ORDER BY created_at) INTO v_drivers
  FROM (SELECT id, created_at FROM public.drivers LIMIT 5) s;

  IF array_length(v_drivers, 1) IS NULL OR array_length(v_drivers, 1) < 2 THEN
    RAISE NOTICE 'SKIP billing table: fewer than 2 drivers in prod';
    RETURN;
  END IF;

  FOR i IN 1..LEAST(array_length(v_drivers, 1), array_length(v_cents, 1)) LOOP
    PERFORM pg_temp._m10b_set_outstanding(v_drivers[i], v_cents[i]);
    PERFORM pg_temp._m10b_ensure_location(
      v_drivers[i],
      v_pickup_lat + (i * 0.0001),
      v_pickup_lon + (i * 0.0001)
    );
  END LOOP;

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, pickup_coords
  )
  VALUES (
    'M10B Sim Pickup', 'M10B Sim Dest', 'pending',
    ST_SetSRID(ST_MakePoint(v_pickup_lon, v_pickup_lat), 4326)::geography
  )
  RETURNING id INTO v_ride;

  v_result := public.fn_seed_ride_matching_batch(v_ride, 4, 30)::json;

  IF (v_result->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'seed failed: %', v_result;
  END IF;

  IF v_result->'skip_metrics' IS NULL THEN
    RAISE EXCEPTION 'missing skip_metrics';
  END IF;

  SELECT array_agg(driver_id) INTO v_invited
  FROM public.ride_request_invites
  WHERE ride_request_id = v_ride AND status = 'pending';

  -- Driver 1 (€0) should be invited if eligible by GPS/status
  IF v_cents[1] < 6000 AND NOT (v_drivers[1] = ANY (COALESCE(v_invited, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'Driver A (€0) should receive invite, invited=%', v_invited;
  END IF;

  -- Any driver at >= €6000 must NOT be invited
  FOR i IN 1..LEAST(array_length(v_drivers, 1), array_length(v_cents, 1)) LOOP
    v_expected_invite := v_cents[i] < 6000;
    IF NOT v_expected_invite AND v_drivers[i] = ANY (COALESCE(v_invited, ARRAY[]::uuid[])) THEN
      RAISE EXCEPTION 'Driver % with % cents must NOT be invited', i, v_cents[i];
    END IF;
  END LOOP;

  RAISE NOTICE 'PASS Test 1: billing invite matrix';
END $$;

-- Test 2: Closest driver locked → next eligible invited
DO $$
DECLARE
  v_d1 uuid; v_d2 uuid;
  v_ride uuid;
  v_result json;
  v_invited uuid[];
BEGIN
  SELECT id INTO v_d1 FROM public.drivers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_d2 FROM public.drivers ORDER BY created_at OFFSET 1 LIMIT 1;
  IF v_d2 IS NULL THEN
    RAISE NOTICE 'SKIP closest-skip test: need 2 drivers';
    RETURN;
  END IF;

  PERFORM pg_temp._m10b_set_outstanding(v_d1, 7500);
  PERFORM pg_temp._m10b_set_outstanding(v_d2, 0);
  PERFORM pg_temp._m10b_ensure_location(v_d1, 51.9225, 4.47917);
  PERFORM pg_temp._m10b_ensure_location(v_d2, 51.9226, 4.47918);

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status,
    pickup_coords
  )
  VALUES (
    'M10B Closest Locked', 'M10B Dest', 'pending',
    ST_SetSRID(ST_MakePoint(4.47917, 51.9225), 4326)::geography
  )
  RETURNING id INTO v_ride;

  v_result := public.fn_seed_ride_matching_batch(v_ride, 1, 30)::json;

  SELECT array_agg(driver_id) INTO v_invited
  FROM public.ride_request_invites WHERE ride_request_id = v_ride;

  IF v_d1 = ANY (COALESCE(v_invited, ARRAY[]::uuid[])) THEN
    RAISE EXCEPTION 'closest locked driver must not be invited';
  END IF;
  IF NOT (v_d2 = ANY (COALESCE(v_invited, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'next eligible driver must be invited, got %', v_invited;
  END IF;

  IF COALESCE((v_result->'skip_metrics'->>'skipped_billing_locked')::int, 0) < 1 THEN
    RAISE EXCEPTION 'skip_metrics must report billing_locked, got %', v_result->'skip_metrics';
  END IF;

  RAISE NOTICE 'PASS Test 2: closest locked → next eligible';
END $$;

-- Test 3: Soft enforcement — 5 candidates, 2 locked, still sends offers
DO $$
DECLARE
  v_drivers uuid[];
  v_ride uuid;
  v_result json;
  v_invited int;
  v_eligible int;
BEGIN
  SELECT array_agg(id) INTO v_drivers FROM (SELECT id FROM public.drivers LIMIT 5) s;
  IF array_length(v_drivers, 1) IS NULL OR array_length(v_drivers, 1) < 3 THEN
    RAISE NOTICE 'SKIP soft enforcement: need 3+ drivers';
    RETURN;
  END IF;

  PERFORM pg_temp._m10b_set_outstanding(v_drivers[1], 7500);
  PERFORM pg_temp._m10b_set_outstanding(v_drivers[2], 6500);
  FOR i IN 3..array_length(v_drivers, 1) LOOP
    PERFORM pg_temp._m10b_set_outstanding(v_drivers[i], 0);
    PERFORM pg_temp._m10b_ensure_location(v_drivers[i], 51.923 + i * 0.0001, 4.48 + i * 0.0001);
  END LOOP;
  PERFORM pg_temp._m10b_ensure_location(v_drivers[1], 51.9225, 4.47917);
  PERFORM pg_temp._m10b_ensure_location(v_drivers[2], 51.92251, 4.47918);

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, pickup_coords
  )
  VALUES (
    'M10B Soft', 'M10B Dest', 'pending',
    ST_SetSRID(ST_MakePoint(4.47917, 51.9225), 4326)::geography
  )
  RETURNING id INTO v_ride;

  v_result := public.fn_seed_ride_matching_batch(v_ride, 4, 30)::json;
  v_invited := COALESCE((v_result->>'invited')::int, 0);
  v_eligible := COALESCE((v_result->'skip_metrics'->>'eligible')::int, 0);

  IF v_invited < 1 AND v_eligible >= 1 THEN
    RAISE EXCEPTION 'must invite at least one when eligible exist: invited=% eligible=%', v_invited, v_eligible;
  END IF;

  RAISE NOTICE 'PASS Test 3: soft enforcement invited=% eligible=%', v_invited, v_eligible;
END $$;

-- Test 4: dispatch.batch_seeded audit row
DO $$
DECLARE
  v_cnt int;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM public.ride_audit_log
  WHERE event = 'dispatch.batch_seeded'
    AND occurred_at > now() - interval '5 minutes';

  IF v_cnt < 1 THEN
    RAISE EXCEPTION 'expected dispatch.batch_seeded audit within transaction';
  END IF;
  RAISE NOTICE 'PASS Test 4: dispatch audit logged';
END $$;

-- Test 5: Radius + billing — closest LOCKED, farther GOOD → farther invited
DO $$
DECLARE
  v_d_near uuid; v_d_far uuid;
  v_ride uuid;
  v_pickup_lat float8 := 51.9225;
  v_pickup_lon float8 := 4.47917;
  v_result json;
  v_invited uuid[];
BEGIN
  SELECT id INTO v_d_near FROM public.drivers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_d_far FROM public.drivers ORDER BY created_at OFFSET 1 LIMIT 1;
  IF v_d_far IS NULL THEN
    RAISE NOTICE 'SKIP radius+billing: need 2 drivers';
    RETURN;
  END IF;

  PERFORM pg_temp._m10b_set_outstanding(v_d_near, 7500);
  PERFORM pg_temp._m10b_set_outstanding(v_d_far, 0);
  -- ~0.5 km north vs ~2 km north (approx 0.0045 vs 0.018 lat degrees)
  PERFORM pg_temp._m10b_ensure_location(v_d_near, v_pickup_lat + 0.0045, v_pickup_lon);
  PERFORM pg_temp._m10b_ensure_location(v_d_far, v_pickup_lat + 0.018, v_pickup_lon);

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, pickup_coords
  )
  VALUES (
    'M10B Radius Billing', 'M10B Dest', 'pending',
    ST_SetSRID(ST_MakePoint(v_pickup_lon, v_pickup_lat), 4326)::geography
  )
  RETURNING id INTO v_ride;

  v_result := public.fn_seed_ride_matching_batch(v_ride, 1, 30)::json;

  IF (v_result->>'dispatch_version')::int IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'expected dispatch_version 1, got %', v_result->>'dispatch_version';
  END IF;
  IF (v_result->>'dispatch_duration_ms') IS NULL THEN
    RAISE EXCEPTION 'missing dispatch_duration_ms';
  END IF;

  SELECT array_agg(driver_id) INTO v_invited
  FROM public.ride_request_invites WHERE ride_request_id = v_ride;

  IF v_d_near = ANY (COALESCE(v_invited, ARRAY[]::uuid[])) THEN
    RAISE EXCEPTION 'near locked driver must not be invited';
  END IF;
  IF NOT (v_d_far = ANY (COALESCE(v_invited, ARRAY[]::uuid[]))) THEN
    RAISE EXCEPTION 'far eligible driver must be invited, got %', v_invited;
  END IF;

  RAISE NOTICE 'PASS Test 5: radius + billing — far eligible wins';
END $$;

ROLLBACK;

SELECT 'M10B_SMOKE_PASSED' AS result;
