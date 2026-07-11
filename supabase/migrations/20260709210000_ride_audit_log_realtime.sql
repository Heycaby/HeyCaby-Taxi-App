-- Publish ride_audit_log to supabase_realtime for debugging.
-- RLS already restricts SELECT to ride participants + admins, so realtime
-- payloads are scoped to the same auth.uid() policies.
-- Sprint 2 item 12.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  )
    AND to_regclass('public.ride_audit_log') IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'ride_audit_log'
    )
  THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_audit_log;
  END IF;
END $$;
