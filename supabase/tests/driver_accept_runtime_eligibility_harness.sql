\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END;
$$;

CREATE TABLE public.drivers (
  id uuid PRIMARY KEY,
  status text,
  compliance_status text,
  vehicle_category text,
  vehicle_type text,
  accepts_pets boolean NOT NULL DEFAULT false,
  is_pet_friendly boolean NOT NULL DEFAULT false,
  is_wheelchair_accessible boolean NOT NULL DEFAULT false,
  wheelchair_accessible boolean NOT NULL DEFAULT false,
  readiness_ok boolean NOT NULL DEFAULT true,
  has_queued_terug boolean NOT NULL DEFAULT false
);

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY,
  vehicle_category text,
  vehicle_categories text[],
  pet_friendly boolean NOT NULL DEFAULT false,
  filter_electric boolean NOT NULL DEFAULT false,
  filter_pet_friendly boolean NOT NULL DEFAULT false,
  filter_wheelchair boolean NOT NULL DEFAULT false
);

CREATE OR REPLACE FUNCTION public.fn_driver_readiness_eval(p_driver_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'can_go_online', d.readiness_ok,
    'status_message', CASE
      WHEN d.readiness_ok THEN 'Ready to go online'
      ELSE 'Complete your launch setup'
    END,
    'missing_docs', CASE
      WHEN d.readiness_ok THEN '[]'::jsonb
      ELSE '["vehicle_plate"]'::jsonb
    END,
    'review_status', 'none'
  )
  FROM public.drivers d
  WHERE d.id = p_driver_id;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_has_queued_taxi_terug(
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(d.has_queued_terug, false)
  FROM public.drivers d
  WHERE d.id = p_driver_id;
$$;

\ir ../migrations/20260714084930_driver_accept_runtime_eligibility.sql
\ir ../migrations/20260714090052_driver_accept_ride_fit_eligibility.sql

DO $$
DECLARE
  v_driver constant uuid := '10000000-0000-0000-0000-000000000001';
  v_ride constant uuid := '20000000-0000-0000-0000-000000000001';
  v_result jsonb;
  v_row public.ride_requests%ROWTYPE;
BEGIN
  INSERT INTO public.drivers (
    id, status, compliance_status, vehicle_category, accepts_pets
  ) VALUES (
    v_driver, 'available', 'compliant', 'comfort', true
  );

  INSERT INTO public.ride_requests (
    id, vehicle_categories, pet_friendly
  ) VALUES (
    v_ride, ARRAY['standard', 'comfort'], true
  );

  SELECT * INTO STRICT v_row
  FROM public.ride_requests
  WHERE id = v_ride;

  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'eligible' <> 'true' THEN
    RAISE EXCEPTION 'eligible Driver rejected: %', v_result;
  END IF;

  UPDATE public.drivers SET status = 'offline' WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'driver_offline' THEN
    RAISE EXCEPTION 'offline Driver was not rejected: %', v_result;
  END IF;

  v_result := public.fn_driver_accept_runtime_eligibility(
    v_driver, v_row, false, false
  );
  IF v_result->>'eligible' <> 'true' THEN
    RAISE EXCEPTION 'offline future-scheduled Driver was rejected: %', v_result;
  END IF;

  UPDATE public.drivers
  SET status = 'available', readiness_ok = false
  WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'driver_not_ready'
     OR v_result->'missing_docs' <> '["vehicle_plate"]'::jsonb THEN
    RAISE EXCEPTION 'readiness rejection contract is wrong: %', v_result;
  END IF;

  UPDATE public.drivers
  SET readiness_ok = true, compliance_status = 'suspended'
  WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'driver_suspended' THEN
    RAISE EXCEPTION 'suspended Driver was not rejected: %', v_result;
  END IF;

  UPDATE public.drivers
  SET compliance_status = 'compliant', has_queued_terug = true
  WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'queued_taxi_terug' THEN
    RAISE EXCEPTION 'queued Driver was not rejected: %', v_result;
  END IF;

  UPDATE public.drivers
  SET has_queued_terug = false, vehicle_category = 'xl'
  WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'vehicle_mismatch' THEN
    RAISE EXCEPTION 'vehicle mismatch was not rejected: %', v_result;
  END IF;

  UPDATE public.drivers
  SET vehicle_category = 'comfort', accepts_pets = false
  WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'pets_not_supported' THEN
    RAISE EXCEPTION 'pet requirement was not rejected: %', v_result;
  END IF;

  UPDATE public.ride_requests
  SET pet_friendly = false,
      filter_electric = true
  WHERE id = v_ride;
  SELECT * INTO STRICT v_row
  FROM public.ride_requests
  WHERE id = v_ride;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'electric_vehicle_required' THEN
    RAISE EXCEPTION 'legacy electric filter was not enforced: %', v_result;
  END IF;

  UPDATE public.ride_requests
  SET filter_electric = false,
      filter_wheelchair = true
  WHERE id = v_ride;
  SELECT * INTO STRICT v_row
  FROM public.ride_requests
  WHERE id = v_ride;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'reason' <> 'wheelchair_vehicle_required' THEN
    RAISE EXCEPTION 'legacy wheelchair filter was not enforced: %', v_result;
  END IF;

  UPDATE public.drivers
  SET wheelchair_accessible = true
  WHERE id = v_driver;
  v_result := public.fn_driver_accept_runtime_eligibility(v_driver, v_row);
  IF v_result->>'eligible' <> 'true' THEN
    RAISE EXCEPTION 'wheelchair-compatible Driver was rejected: %', v_result;
  END IF;

  IF has_function_privilege(
    'anon',
    'public.fn_driver_accept_runtime_eligibility(uuid, public.ride_requests)',
    'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'public.fn_driver_accept_runtime_eligibility(uuid, public.ride_requests)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'internal eligibility helper remains client-callable';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.fn_driver_accept_runtime_eligibility(uuid, public.ride_requests, boolean, boolean)',
    'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'public.fn_driver_accept_runtime_eligibility(uuid, public.ride_requests, boolean, boolean)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'context eligibility helper remains client-callable';
  END IF;
END;
$$;

ROLLBACK;

\echo driver_accept_runtime_eligibility_passed
