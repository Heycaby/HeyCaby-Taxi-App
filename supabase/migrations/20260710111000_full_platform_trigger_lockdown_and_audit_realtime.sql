-- Full-platform stabilization follow-up.
-- Trigger functions execute through PostgreSQL triggers and are not client RPCs.
-- Removing direct app-role execution closes an unnecessary security surface
-- without changing trigger behavior.

DO $migration$
DECLARE
  trigger_function record;
BEGIN
  FOR trigger_function IN
    SELECT DISTINCT
      namespace.nspname AS schema_name,
      procedure.proname AS function_name,
      pg_get_function_identity_arguments(procedure.oid) AS function_arguments
    FROM pg_trigger AS trigger_definition
    JOIN pg_proc AS procedure
      ON procedure.oid = trigger_definition.tgfoid
    JOIN pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE NOT trigger_definition.tgisinternal
      AND namespace.nspname = 'public'
  LOOP
    EXECUTE format(
      'REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC, anon, authenticated',
      trigger_function.schema_name,
      trigger_function.function_name,
      trigger_function.function_arguments
    );
    EXECUTE format(
      'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO service_role',
      trigger_function.schema_name,
      trigger_function.function_name,
      trigger_function.function_arguments
    );
  END LOOP;
END
$migration$;

-- Lifecycle audit events drive participant-scoped recovery and diagnostics.
-- RLS remains the authorization boundary for Realtime delivery.
DO $migration$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
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
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.ride_audit_log;
  END IF;
END
$migration$;
