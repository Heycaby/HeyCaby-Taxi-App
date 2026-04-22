-- App + docs use vehicle keys: standard | comfort | taxibus | wheelchair.
-- Some projects introduced a Postgres enum `vehicle_category` before "taxibus"
-- existed on that type, which causes:
--   invalid input value for enum vehicle_category: "taxibus" (22P02)
-- This migration extends the enum when present; no-op if type is text-only or value exists.

DO $body$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'vehicle_category'
      AND t.typtype = 'e'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_enum e
      JOIN pg_type t ON t.oid = e.enumtypid
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public'
        AND t.typname = 'vehicle_category'
        AND e.enumlabel = 'taxibus'
    ) THEN
      ALTER TYPE public.vehicle_category ADD VALUE 'taxibus';
    END IF;
  END IF;
END
$body$;
