-- Phase 3 M10A smoke (ROLLBACK — no permanent data).

BEGIN;

-- GOOD: zero outstanding
DO $$
DECLARE
  v_driver uuid;
  v_check jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  IF v_driver IS NULL THEN RAISE EXCEPTION 'no driver'; END IF;

  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'allowed')::boolean <> true THEN
    RAISE EXCEPTION 'expected allowed=true at zero outstanding, got %', v_check;
  END IF;
  IF v_check->>'status' <> 'GOOD' THEN
    RAISE EXCEPTION 'expected GOOD, got %', v_check->>'status';
  END IF;
END $$;

-- LOCKED: outstanding >= limit (6000 NL)
DO $$
DECLARE
  v_driver uuid;
  v_check jsonb;
  g int;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;

  FOR g IN 1..61 LOOP
    INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
    VALUES (v_driver, 100, 'manual_adjustment', jsonb_build_object('smoke', g));
  END LOOP;

  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'allowed')::boolean <> false THEN
    RAISE EXCEPTION 'expected allowed=false at 6100 cents, got %', v_check;
  END IF;
  IF v_check->>'status' <> 'LOCKED' THEN
    RAISE EXCEPTION 'expected LOCKED, got %', v_check->>'status';
  END IF;
  IF v_check->>'reason' IS NULL THEN
    RAISE EXCEPTION 'expected reason text when locked';
  END IF;
END $$;

-- Summary RPC shape
DO $$
DECLARE
  v_driver uuid;
  v_summary jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;
  v_summary := public.fn_driver_billing_summary(v_driver);
  IF v_summary->>'currency' IS NULL
     OR v_summary->>'status' IS NULL
     OR v_summary->>'limit' IS NULL THEN
    RAISE EXCEPTION 'summary missing fields: %', v_summary;
  END IF;

  IF (public.fn_driver_platform_health(v_driver)->>'allowed') IS NULL THEN
    RAISE EXCEPTION 'platform_health missing allowed';
  END IF;
END $$;

-- Derived unlock: settlement reduces outstanding
DO $$
DECLARE
  v_driver uuid;
  v_check jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers LIMIT 1;

  INSERT INTO public.billing_ledger (driver_id, amount_cents, reason, metadata)
  VALUES (v_driver, -6100, 'settlement', '{"smoke": "paydown"}'::jsonb);

  v_check := public.fn_driver_can_accept_rides(v_driver);
  IF (v_check->>'allowed')::boolean <> true THEN
    RAISE EXCEPTION 'expected allowed after settlement, got %', v_check;
  END IF;
END $$;

ROLLBACK;

SELECT 'M10A_SMOKE_PASSED' AS result;
