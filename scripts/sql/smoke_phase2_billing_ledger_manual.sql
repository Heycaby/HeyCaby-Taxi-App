-- Phase 2 Step 3: Full validation checklist (ROLLBACK — no permanent data).
-- Run AFTER v1_phase2_billing_ledger_schema_only migration.

BEGIN;

-- 1) market_config
DO $$
DECLARE
  fee jsonb;
  lim jsonb;
BEGIN
  fee := public.fn_get_market_config('platform_fee_cents', 'NL');
  lim := public.fn_get_market_config('outstanding_limit_cents', 'NL');
  IF fee IS DISTINCT FROM '100'::jsonb THEN
    RAISE EXCEPTION 'platform_fee_cents expected 100, got %', fee;
  END IF;
  IF lim IS DISTINCT FROM '6000'::jsonb THEN
    RAISE EXCEPTION 'outstanding_limit_cents expected 6000, got %', lim;
  END IF;
  RAISE NOTICE 'PASS: market_config NL defaults';
END $$;

-- 2) Manual ledger entry + ledger_sequence + balance view
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_id uuid;
  v_seq bigint;
  v_balance bigint;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'No driver row — cannot smoke test ledger';
  END IF;

  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('Smoke Manual', 'Smoke Manual Dest', 'cancelled')
  RETURNING id INTO v_ride;

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id, metadata)
  VALUES (v_driver, 100, 'ride_fee', v_ride, '{"smoke": "manual"}'::jsonb)
  RETURNING id, ledger_sequence INTO v_id, v_seq;

  IF v_seq IS NULL OR v_seq < 1 THEN
    RAISE EXCEPTION 'ledger_sequence not assigned';
  END IF;

  SELECT outstanding_cents INTO v_balance
  FROM public.driver_platform_balance
  WHERE driver_id = v_driver;

  IF v_balance IS NULL THEN
    RAISE EXCEPTION 'balance view missing driver row';
  END IF;

  RAISE NOTICE 'PASS: manual ride_fee seq=% balance=%', v_seq, v_balance;
END $$;

-- 3) Reversal append (never UPDATE ledger rows)
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('Smoke Reversal', 'Smoke Reversal Dest', 'cancelled')
  RETURNING id INTO v_ride;

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id)
  VALUES (v_driver, 100, 'ride_fee', v_ride);

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id, metadata)
  VALUES (v_driver, -100, 'reversal', v_ride, '{"smoke": "refund"}'::jsonb);

  RAISE NOTICE 'PASS: reversal append';
END $$;

-- 4) Duplicate ride_fee protection
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('Smoke Dup A', 'Smoke Dup B', 'cancelled')
  RETURNING id INTO v_ride;

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id)
  VALUES (v_driver, 100, 'ride_fee', v_ride);

  BEGIN
    INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id)
    VALUES (v_driver, 100, 'ride_fee', v_ride);
    RAISE EXCEPTION 'FAIL: duplicate ride_fee should have been rejected';
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'PASS: duplicate ride_fee prevented';
  END;
END $$;

-- 5) Concurrency simulation (same ride, two inserts — second must fail)
DO $$
DECLARE
  v_driver uuid;
  v_ride uuid;
  v_ok int := 0;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  INSERT INTO public.ride_requests (pickup_address, destination_address, status)
  VALUES ('Smoke Conc A', 'Smoke Conc B', 'cancelled')
  RETURNING id INTO v_ride;

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id)
  VALUES (v_driver, 100, 'ride_fee', v_ride);
  v_ok := v_ok + 1;

  BEGIN
    INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, ride_id)
    VALUES (v_driver, 100, 'ride_fee', v_ride);
    v_ok := v_ok + 1;
  EXCEPTION
    WHEN unique_violation THEN NULL;
  END;

  IF v_ok <> 1 THEN
    RAISE EXCEPTION 'FAIL: concurrency test expected exactly 1 insert, got %', v_ok;
  END IF;
  RAISE NOTICE 'PASS: concurrency duplicate blocked';
END $$;

-- 6) Performance sample (1000 rows; full 100k on staging before high volume)
DO $$
DECLARE
  v_driver uuid;
  t0 timestamptz;
  t1 timestamptz;
  v_balance bigint;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  t0 := clock_timestamp();

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
  SELECT v_driver, 100, 'manual_adjustment', jsonb_build_object('perf', g)
  FROM generate_series(1, 1000) g;

  SELECT COALESCE(SUM(amount_cents), 0) INTO v_balance
  FROM public.billing_ledger
  WHERE driver_id = v_driver;

  t1 := clock_timestamp();
  RAISE NOTICE 'PASS: perf sample 1000 inserts + sum in % ms, balance=%',
    EXTRACT(MILLISECONDS FROM (t1 - t0)), v_balance;
END $$;

ROLLBACK;
