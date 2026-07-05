-- Keep staging and production aligned for the live driver-location surface.
-- Production already had driver_locations in Supabase Realtime; staging did
-- not. This is idempotent and therefore safe on both projects.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'driver_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;
  END IF;
END $$;
