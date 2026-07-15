-- Disposable PostgreSQL harness. Never run against a shared database.

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

CREATE FUNCTION public.fn_driver_decline_ride_invite(uuid) RETURNS json LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::json $$;
CREATE FUNCTION public.fn_driver_ride_cancel(uuid,text) RETURNS json LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::json $$;
CREATE FUNCTION public.fn_driver_ride_en_route(uuid) RETURNS json LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::json $$;
CREATE FUNCTION public.fn_driver_ride_no_show(uuid) RETURNS json LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::json $$;
CREATE FUNCTION public.fn_app_notifications_list(text,boolean,integer,uuid,integer) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_app_notification_mark_read(uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_app_notifications_mark_all_read(text,uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_app_notifications_clear_read(text,uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_app_notifications_delete_all(text,uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_app_notifications_delete_ids(uuid[],text,uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_app_notification_owner_ids(text,uuid) RETURNS text[] LANGUAGE sql SECURITY DEFINER AS $$ SELECT ARRAY[]::text[] $$;
CREATE FUNCTION public.fn_driver_ride_lifecycle_resolve_driver() RETURNS uuid LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid $$;
CREATE FUNCTION public.fn_driver_ride_lifecycle_audit(uuid,text,uuid,jsonb) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_maybe_notify_near_pickup_for_driver(uuid) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_process_scheduled_rides_no_driver() RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_recalculate_ride_fare(uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.simulate_driver_movement() RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_shift_handover_notify_fleet_owner(uuid,text,text,jsonb) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_shift_handover_notify_private_owner_attempt(uuid,uuid,text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  TO PUBLIC, anon, authenticated, service_role;

\ir ../migrations/20260714075642_lifecycle_notification_internal_grant_boundary.sql
\ir lifecycle_notification_internal_grant_boundary_test.sql
