-- Minimal disposable PostgreSQL harness for the Rider ping projection.
-- Never run this harness against a shared or production database.

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

CREATE SCHEMA private;

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY,
  booking_mode text
);

CREATE TABLE public.ride_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL,
  event text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ride_audit_log_ride_occurred
  ON public.ride_audit_log (ride_id, occurred_at DESC);

CREATE FUNCTION private.fn_rider_ride_snapshot_base(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.ride_requests WHERE id = p_ride_request_id
    ) THEN jsonb_build_object(
      'ok', true,
      'id', p_ride_request_id,
      'updated_at', '2026-07-14T07:00:00Z'
    )
    ELSE jsonb_build_object('ok', false, 'code', 'ride_not_found')
  END;
$$;

REVOKE ALL ON FUNCTION private.fn_rider_ride_snapshot_base(uuid, text)
  FROM PUBLIC, anon, authenticated;

INSERT INTO public.ride_requests (id, booking_mode) VALUES
  ('00000000-0000-0000-0000-000000000071', 'instant'),
  ('00000000-0000-0000-0000-000000000072', 'terug');

INSERT INTO public.ride_audit_log (id, ride_id, event, occurred_at) VALUES
  (
    '00000000-0000-0000-0000-000000000081',
    '00000000-0000-0000-0000-000000000071',
    'driver.ping_on_my_way',
    '2026-07-14T07:01:00Z'
  ),
  (
    '00000000-0000-0000-0000-000000000082',
    '00000000-0000-0000-0000-000000000071',
    'driver.ping_on_my_way.delivered',
    '2026-07-14T07:01:02Z'
  ),
  (
    '00000000-0000-0000-0000-000000000083',
    '00000000-0000-0000-0000-000000000071',
    'driver.ping_outside',
    '2026-07-14T07:02:00Z'
  );

\ir ../migrations/20260714073821_rider_snapshot_ping_projection.sql
\ir rider_snapshot_ping_projection_test.sql
