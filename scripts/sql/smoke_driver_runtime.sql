-- Smoke: driver runtime consolidation (run as service_role or authenticated driver).
-- Expect ok=true, readiness.checklist array, platform_health_legacy.allowed key present.

DO $$
DECLARE
  v_driver uuid;
  v_runtime jsonb;
  v_health jsonb;
BEGIN
  SELECT id INTO v_driver FROM public.drivers ORDER BY created_at DESC LIMIT 1;
  IF v_driver IS NULL THEN
    RAISE NOTICE 'SKIP: no drivers row';
    RETURN;
  END IF;

  v_runtime := public.fn_driver_runtime(v_driver);
  IF COALESCE(v_runtime->>'ok', 'false') <> 'true' THEN
    RAISE EXCEPTION 'fn_driver_runtime failed: %', v_runtime;
  END IF;

  IF COALESCE((v_runtime->>'runtime_version')::int, 0) < 3 THEN
    RAISE EXCEPTION 'expected runtime_version >= 3, got %', v_runtime->>'runtime_version';
  END IF;

  IF v_runtime->>'generated_at' IS NULL THEN
    RAISE EXCEPTION 'missing generated_at';
  END IF;

  IF v_runtime->'readiness'->'checklist' IS NULL THEN
    RAISE EXCEPTION 'missing readiness.checklist';
  END IF;

  IF v_runtime->'config'->'feature_flags' IS NULL THEN
    RAISE EXCEPTION 'missing config.feature_flags';
  END IF;

  v_health := public.fn_driver_platform_health(v_driver);
  IF v_health->'allowed' IS NULL THEN
    RAISE EXCEPTION 'platform_health missing allowed';
  END IF;

  RAISE NOTICE 'OK driver runtime smoke for driver %', v_driver;
END;
$$;
