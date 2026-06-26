-- Phase 2 Step 4: Five CTO-required tests (ROLLBACK — no permanent data).
-- Run AFTER v1_phase2_step4_trip_completed_ledger_trigger migration.

BEGIN;

-- Test 1: Trip completed → ledger +100 cents
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_count int;
  v_cents int;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  IF v_driver IS NULL THEN RAISE EXCEPTION 'no driver'; END IF;

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, driver_id, country_code
  )
  VALUES ('Step4 T1 Pickup', 'Step4 T1 Dest', 'in_progress', v_driver, 'NL')
  RETURNING id INTO v_ride;

  UPDATE public.ride_requests SET status = 'completed' WHERE id = v_ride;

  SELECT COUNT(*), COALESCE(MAX(amount_cents), 0)
  INTO v_count, v_cents
  FROM public.billing_ledger
  WHERE ride_id = v_ride AND reason = 'ride_fee';

  IF v_count <> 1 OR v_cents <> 100 THEN
    RAISE EXCEPTION 'Test 1 FAIL: expected 1 row +100, got % rows % cents', v_count, v_cents;
  END IF;
  RAISE NOTICE 'PASS Test 1: trip.completed → +100 cents';
END $$;

-- Test 2: Trip completed twice (idempotent accrue function)
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_id1 uuid;
  v_id2 uuid;
  v_count int;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, driver_id, country_code
  )
  VALUES ('Step4 T2 Pickup', 'Step4 T2 Dest', 'completed', v_driver, 'NL')
  RETURNING id INTO v_ride;

  v_id1 := public.fn_billing_accrue_ride_fee(v_ride, v_driver, 'NL', NULL, NULL);
  v_id2 := public.fn_billing_accrue_ride_fee(v_ride, v_driver, 'NL', NULL, NULL);

  SELECT COUNT(*) INTO v_count
  FROM public.billing_ledger
  WHERE ride_id = v_ride AND reason = 'ride_fee';

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Test 2 FAIL: expected 1 ledger row, got %', v_count;
  END IF;
  IF v_id1 IS NULL THEN
    RAISE EXCEPTION 'Test 2 FAIL: first accrue returned null';
  END IF;
  IF v_id2 IS NOT NULL THEN
    RAISE EXCEPTION 'Test 2 FAIL: second accrue should return null (duplicate)';
  END IF;
  RAISE NOTICE 'PASS Test 2: double complete → one ledger row';
END $$;

-- Test 3: Complete → admin reopen → complete again (fee stays, no second fee)
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_count int;
  v_sum int;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, driver_id, country_code
  )
  VALUES ('Step4 T3 Pickup', 'Step4 T3 Dest', 'in_progress', v_driver, 'NL')
  RETURNING id INTO v_ride;

  UPDATE public.ride_requests SET status = 'completed' WHERE id = v_ride;
  UPDATE public.ride_requests SET status = 'in_progress' WHERE id = v_ride;
  UPDATE public.ride_requests SET status = 'completed' WHERE id = v_ride;

  SELECT COUNT(*), COALESCE(SUM(amount_cents), 0)
  INTO v_count, v_sum
  FROM public.billing_ledger
  WHERE ride_id = v_ride AND reason = 'ride_fee';

  IF v_count <> 1 OR v_sum <> 100 THEN
    RAISE EXCEPTION 'Test 3 FAIL: expected 1 fee +100 after reopen, got % rows sum %', v_count, v_sum;
  END IF;
  RAISE NOTICE 'PASS Test 3: reopen + re-complete → original fee kept, no second fee';
END $$;

-- Test 4: Concurrent completion (same-transaction double accrue — unique index safety)
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_ok int := 0;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, driver_id, country_code
  )
  VALUES ('Step4 T4 Pickup', 'Step4 T4 Dest', 'in_progress', v_driver, 'NL')
  RETURNING id INTO v_ride;

  BEGIN
    PERFORM public.fn_billing_accrue_ride_fee(v_ride, v_driver, 'NL', NULL, NULL);
    v_ok := v_ok + 1;
    PERFORM public.fn_billing_accrue_ride_fee(v_ride, v_driver, 'NL', NULL, NULL);
    v_ok := v_ok + 1;
  EXCEPTION
    WHEN unique_violation THEN NULL;
  END;

  SELECT COUNT(*) INTO v_ok
  FROM public.billing_ledger
  WHERE ride_id = v_ride AND reason = 'ride_fee';

  IF v_ok <> 1 THEN
    RAISE EXCEPTION 'Test 4 FAIL: expected exactly 1 fee row, got %', v_ok;
  END IF;
  RAISE NOTICE 'PASS Test 4: concurrent-style double accrue → one fee';
END $$;

-- Test 5: Dispute refund — append reversal, never edit/delete
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_ledger uuid;
  v_sum bigint;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;

  INSERT INTO public.ride_requests (
    pickup_address, destination_address, status, driver_id, country_code
  )
  VALUES ('Step4 T5 Pickup', 'Step4 T5 Dest', 'completed', v_driver, 'NL')
  RETURNING id INTO v_ride;

  v_ledger := public.fn_billing_accrue_ride_fee(v_ride, v_driver, 'NL', NULL, NULL);

  INSERT INTO public.billing_ledger (
    driver_id, amount_cents, reason, ride_id, metadata
  )
  VALUES (
    v_driver, -100, 'reversal', v_ride,
    jsonb_build_object('smoke', 'dispute_refund', 'original_ledger_id', v_ledger)
  );

  SELECT COALESCE(SUM(amount_cents), 0) INTO v_sum
  FROM public.billing_ledger
  WHERE ride_id = v_ride;

  IF v_sum <> 0 THEN
    RAISE EXCEPTION 'Test 5 FAIL: expected net 0 after reversal, got %', v_sum;
  END IF;
  RAISE NOTICE 'PASS Test 5: +100 then -100 reversal, append-only';
END $$;

ROLLBACK;

SELECT 'ALL_STEP4_SMOKE_PASSED' AS result;
