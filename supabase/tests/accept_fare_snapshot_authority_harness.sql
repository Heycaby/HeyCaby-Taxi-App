-- Minimal isolated PostgreSQL harness for accept_fare_snapshot_authority.
-- Run only against a disposable database; the production-shaped contract test
-- itself lives in accept_fare_snapshot_authority_test.sql.

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

CREATE SCHEMA private;

CREATE TABLE public.driver_rate_profiles (
  id uuid PRIMARY KEY,
  driver_id uuid NOT NULL,
  base_fare numeric NOT NULL,
  per_km_rate numeric NOT NULL,
  per_min_rate numeric NOT NULL,
  minimum_fare numeric NOT NULL,
  is_active boolean NOT NULL,
  sort_order smallint NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY,
  status text NOT NULL,
  driver_id uuid,
  booking_mode text,
  final_fare numeric,
  quoted_fare numeric,
  offered_fare numeric,
  marketplace_offered_fare numeric,
  estimated_fare numeric,
  estimated_distance_km numeric,
  estimated_duration_min numeric
);

CREATE TABLE public.ride_audit_log (
  ride_id uuid,
  event text,
  actor_id uuid,
  metadata jsonb,
  actor_type text,
  source text,
  correlation_id uuid
);

CREATE FUNCTION public.fn_ride_audit_append(
  p_ride_id uuid,
  p_event text,
  p_actor_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_actor_type text DEFAULT NULL,
  p_source text DEFAULT NULL,
  p_correlation_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE sql
AS $$
  INSERT INTO public.ride_audit_log (
    ride_id, event, actor_id, metadata, actor_type, source, correlation_id
  )
  VALUES (
    p_ride_id, p_event, p_actor_id, p_metadata, p_actor_type, p_source,
    p_correlation_id
  );
$$;

INSERT INTO public.driver_rate_profiles (
  id,
  driver_id,
  base_fare,
  per_km_rate,
  per_min_rate,
  minimum_fare,
  is_active,
  sort_order,
  updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000201',
  4.25,
  1.85,
  0.35,
  7.50,
  true,
  0,
  now()
);

\ir ../migrations/20260714070835_accept_fare_snapshot_authority.sql
\ir accept_fare_snapshot_authority_test.sql
