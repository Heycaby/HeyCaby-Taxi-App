\set ON_ERROR_STOP on

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS private;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('test.uid', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('test.jwt', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

CREATE TYPE public.booking_mode AS ENUM (
  'instant', 'scheduled', 'marketplace', 'terug'
);
CREATE TYPE public.vehicle_category AS ENUM (
  'standard', 'comfort', 'xl', 'wheelchair', 'electric', 'taxibus'
);
CREATE DOMAIN public.geography AS text;

CREATE TABLE public.rider_sessions (
  session_token text PRIMARY KEY,
  user_id uuid
);

CREATE TABLE public.rider_identities (
  id uuid PRIMARY KEY,
  email text,
  email_verified_at timestamptz,
  user_id uuid,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.drivers (
  id uuid PRIMARY KEY
);

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pickup_address text NOT NULL,
  pickup_coords public.geography,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_address text NOT NULL,
  destination_coords public.geography,
  destination_lat double precision,
  destination_lng double precision,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  booking_mode public.booking_mode NOT NULL DEFAULT 'instant',
  vehicle_category public.vehicle_category,
  vehicle_categories text[],
  pet_friendly boolean NOT NULL DEFAULT false,
  estimated_distance_km numeric,
  estimated_duration_min numeric,
  pickup_contact_name text,
  scheduled_pickup_at timestamptz,
  rider_token text,
  rider_identity_id uuid,
  marketplace_offered_fare numeric,
  offered_fare numeric,
  quoted_fare numeric,
  estimated_fare numeric,
  preferred_driver_id uuid,
  payment_methods text[],
  favorites_first boolean NOT NULL DEFAULT false,
  favorites_only boolean DEFAULT false
);

\ir ../migrations/20260714082656_rider_create_ride_command_authority.sql

DO $$
DECLARE
  v_actor constant uuid := '10000000-0000-0000-0000-000000000001';
  v_other constant uuid := '10000000-0000-0000-0000-000000000002';
  v_identity constant uuid := '20000000-0000-0000-0000-000000000001';
  v_request constant uuid := '30000000-0000-0000-0000-000000000001';
  v_payload jsonb;
  v_first jsonb;
  v_retry jsonb;
  v_result jsonb;
  v_row public.ride_requests%ROWTYPE;
BEGIN
  v_payload := jsonb_build_object(
    'request_id', v_request,
    'rider_token', 'session-a',
    'rider_identity_id', v_identity,
    'pickup_lat', 52.3676,
    'pickup_lng', 4.9041,
    'destination_lat', 51.9244,
    'destination_lng', 4.4777,
    'pickup_address', 'Amsterdam Centraal',
    'destination_address', 'Rotterdam Centraal',
    'pickup_contact_name', 'Rider Test',
    'estimated_distance_km', 74.2,
    'estimated_duration_min', 58,
    'booking_mode', 'marketplace',
    'vehicle_category', 'comfort',
    'vehicle_categories', jsonb_build_array('comfort', 'standard'),
    'payment_methods', jsonb_build_array('pin', 'cash'),
    'marketplace_offered_fare', 88.50,
    'pet_friendly', true,
    'favorites_only', true
  );

  v_result := public.fn_rider_create_ride(v_payload);
  IF v_result->>'error' <> 'unauthorized' THEN
    RAISE EXCEPTION 'anonymous invocation did not fail closed: %', v_result;
  END IF;

  INSERT INTO public.rider_sessions(session_token, user_id)
  VALUES ('session-a', v_actor);
  INSERT INTO public.rider_identities(
    id, email, email_verified_at, user_id
  ) VALUES (
    v_identity, 'rider@example.test', now(), v_actor
  );

  PERFORM set_config('test.uid', v_actor::text, true);
  PERFORM set_config(
    'test.jwt',
    jsonb_build_object('email', 'rider@example.test')::text,
    true
  );

  v_first := public.fn_rider_create_ride(v_payload);
  IF v_first->>'ok' <> 'true' OR v_first->>'duplicate' <> 'false' THEN
    RAISE EXCEPTION 'valid booking failed: %', v_first;
  END IF;

  SELECT * INTO STRICT v_row
  FROM public.ride_requests
  WHERE id = (v_first->>'id')::uuid;

  IF v_row.status <> 'pending'
     OR v_row.booking_mode <> 'marketplace'
     OR v_row.pickup_lat <> 52.3676
     OR v_row.destination_lng <> 4.4777
     OR v_row.pickup_coords NOT LIKE 'SRID=4326;POINT(4.9041 52.3676)%'
     OR v_row.marketplace_offered_fare <> 88.50
     OR v_row.offered_fare <> 88.50
     OR v_row.quoted_fare <> 88.50
     OR v_row.estimated_fare <> 88.50
     OR NOT v_row.favorites_first
     OR NOT v_row.favorites_only THEN
    RAISE EXCEPTION 'canonical booking projection is wrong: %', row_to_json(v_row);
  END IF;

  v_retry := public.fn_rider_create_ride(v_payload);
  IF v_retry->>'ok' <> 'true' OR v_retry->>'duplicate' <> 'true'
     OR v_retry->>'id' <> v_first->>'id' THEN
    RAISE EXCEPTION 'idempotent retry failed: %', v_retry;
  END IF;
  IF (SELECT count(*) FROM public.ride_requests) <> 1 THEN
    RAISE EXCEPTION 'idempotent retry inserted a duplicate';
  END IF;

  v_result := public.fn_rider_create_ride(
    jsonb_set(v_payload, '{pickup_address}', '"Different"'::jsonb)
  );
  IF v_result->>'error' <> 'idempotency_conflict' THEN
    RAISE EXCEPTION 'changed retry did not conflict: %', v_result;
  END IF;

  PERFORM set_config('test.uid', v_other::text, true);
  v_result := public.fn_rider_create_ride(
    jsonb_set(
      v_payload,
      '{request_id}',
      to_jsonb('30000000-0000-0000-0000-000000000002'::text)
    )
  );
  IF v_result->>'error' <> 'rider_session_mismatch' THEN
    RAISE EXCEPTION 'cross-user session was accepted: %', v_result;
  END IF;

  IF has_function_privilege('anon', 'public.fn_rider_create_ride(jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon retains create command execution';
  END IF;
  IF NOT has_function_privilege(
    'authenticated', 'public.fn_rider_create_ride(jsonb)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated lacks create command execution';
  END IF;
END;
$$;

ROLLBACK;

DO $$
BEGIN
  IF to_regprocedure('public.fn_rider_create_ride(jsonb)') IS NOT NULL THEN
    RAISE EXCEPTION 'rollback did not remove the test function';
  END IF;
END;
$$;

\echo rider_create_ride_command_authority_passed
