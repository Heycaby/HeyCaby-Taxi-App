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

CREATE TYPE public.booking_mode AS ENUM (
  'instant', 'scheduled', 'marketplace', 'terug'
);
CREATE DOMAIN public.geometry AS text;

CREATE OR REPLACE FUNCTION public.st_x(public.geometry)
RETURNS double precision LANGUAGE sql IMMUTABLE AS $$ SELECT 0::float8 $$;
CREATE OR REPLACE FUNCTION public.st_y(public.geometry)
RETURNS double precision LANGUAGE sql IMMUTABLE AS $$ SELECT 0::float8 $$;
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULL::uuid $$;

CREATE TABLE public.bubble_zones (
  id uuid PRIMARY KEY,
  name_display text,
  city text
);

CREATE TABLE public.drivers (
  id uuid PRIMARY KEY,
  user_id uuid,
  full_name text,
  vehicle_make text,
  vehicle_model text,
  vehicle_plate text
);

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY,
  pickup_address text,
  destination_address text,
  scheduled_pickup_at timestamptz,
  estimated_distance_km numeric,
  estimated_duration_min numeric,
  offered_fare numeric,
  marketplace_offered_fare numeric,
  payment_method text,
  payment_methods text[],
  pickup_contact_name text,
  zone_id uuid,
  pickup_coords public.geometry,
  destination_coords public.geometry,
  filter_electric boolean,
  filter_pet_friendly boolean,
  filter_wheelchair boolean,
  created_at timestamptz,
  status text,
  expires_at timestamptz,
  driver_id uuid,
  booking_mode public.booking_mode,
  is_scheduled boolean,
  rider_identity_id uuid,
  accepted_at timestamptz,
  scheduled_confirmed_by_driver boolean,
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
  status text
);

CREATE OR REPLACE FUNCTION public.fn_driver_accept_runtime_eligibility(
  p_driver_id uuid,
  p_ride public.ride_requests,
  p_require_online boolean,
  p_block_queued_taxi_terug boolean
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$ SELECT '{"eligible":true}'::jsonb $$;

\ir ../migrations/20260714090109_scheduled_accept_authority.sql

DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.fn_driver_accept_scheduled_ride(uuid)'::regprocedure
  ) INTO v_definition;

  IF v_definition NOT LIKE '%FOR UPDATE%'
     OR v_definition NOT LIKE '%scheduled_departed%'
     OR v_definition NOT LIKE '%fn_driver_accept_runtime_eligibility%'
     OR v_definition NOT LIKE '%fn_driver_has_overlap%'
     OR v_definition NOT LIKE '%fn_ride_notify_rider%'
     OR v_definition NOT LIKE '%dispatch.scheduled_accept_rejected%' THEN
    RAISE EXCEPTION 'scheduled accept function is missing an invariant';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class c
    WHERE c.oid = 'public.scheduled_rides_available'::regclass
      AND 'security_invoker=true' = ANY (c.reloptions)
  ) THEN
    RAISE EXCEPTION 'scheduled view is not security_invoker';
  END IF;

  IF has_function_privilege(
    'anon', 'public.fn_driver_accept_scheduled_ride(uuid)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon retains scheduled accept execution';
  END IF;
  IF NOT has_function_privilege(
    'authenticated', 'public.fn_driver_accept_scheduled_ride(uuid)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated lacks scheduled accept execution';
  END IF;
END;
$$;

ROLLBACK;

\echo scheduled_accept_authority_compiled
