\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA auth;

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

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$ SELECT NULL::uuid $$;

CREATE TABLE public.drivers (
  id uuid PRIMARY KEY,
  user_id uuid,
  full_name text
);

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY,
  status text,
  driver_id uuid,
  cancelled_by text,
  cancellation_reason text,
  expires_at timestamptz,
  payment_methods text[],
  rider_identity_id uuid,
  accepted_at timestamptz,
  updated_at timestamptz
);

CREATE TABLE public.conversations (
  id uuid PRIMARY KEY,
  ride_request_id uuid UNIQUE,
  driver_id uuid,
  rider_identity_id uuid
);

CREATE TABLE public.driver_rate_profiles (
  driver_id uuid,
  is_active boolean
);

CREATE TABLE public.driver_locations (
  driver_id uuid,
  latitude double precision,
  longitude double precision,
  updated_at timestamptz
);

CREATE TABLE public.ride_request_invites (
  ride_request_id uuid,
  driver_id uuid,
  status text,
  expires_at timestamptz
);

CREATE OR REPLACE FUNCTION public.fn_driver_accept_runtime_eligibility(
  p_driver_id uuid,
  p_ride public.ride_requests
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$ SELECT '{"eligible":true}'::jsonb $$;

\ir ../migrations/20260714084941_driver_accept_runtime_recheck.sql

DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.fn_driver_accept_ride_invite(uuid)'::regprocedure
  ) INTO v_definition;

  IF v_definition NOT LIKE '%FOR UPDATE%'
     OR v_definition NOT LIKE '%ride_expired%'
     OR v_definition NOT LIKE '%fn_driver_accept_runtime_eligibility%'
     OR v_definition NOT LIKE '%status = ''superseded''%' THEN
    RAISE EXCEPTION 'compiled accept function is missing a required invariant';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.fn_driver_accept_ride_invite(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon retains accept execution';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.fn_driver_accept_ride_invite(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated lacks accept execution';
  END IF;
END;
$$;

ROLLBACK;

\echo driver_accept_runtime_recheck_compiled
