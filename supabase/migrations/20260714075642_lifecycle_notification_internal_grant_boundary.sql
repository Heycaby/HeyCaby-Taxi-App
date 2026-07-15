-- Restore the released client-command versus internal-helper execution
-- boundary. Current Driver and shared API callers use only the four public
-- lifecycle commands and six notification commands below. Their implementations
-- already resolve the authenticated actor server-side. Anonymous execution is
-- neither required nor useful because auth.uid() is mandatory.

REVOKE ALL ON FUNCTION public.fn_driver_decline_ride_invite(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_decline_ride_invite(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_ride_cancel(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_cancel(uuid, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_ride_en_route(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_en_route(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_driver_ride_no_show(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_no_show(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_app_notifications_list(
  text, boolean, integer, uuid, integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_list(
  text, boolean, integer, uuid, integer
) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_app_notification_mark_read(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_app_notification_mark_read(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_app_notifications_mark_all_read(text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_mark_all_read(text, uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_app_notifications_clear_read(text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_clear_read(text, uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_app_notifications_delete_all(text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_delete_all(text, uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_app_notifications_delete_ids(
  uuid[], text, uuid
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_app_notifications_delete_ids(
  uuid[], text, uuid
) TO authenticated, service_role;

-- The following functions are reached only from owner-context database
-- functions/triggers, pg_cron, or service-role Edge Functions. Keeping them
-- directly executable by clients creates a second command path.

REVOKE ALL ON FUNCTION public.fn_app_notification_owner_ids(text, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_resolve_driver()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_ride_lifecycle_audit(
  uuid, text, uuid, jsonb
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_maybe_notify_near_pickup_for_driver(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_process_scheduled_rides_no_driver()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_recalculate_ride_fare(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.simulate_driver_movement()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_notify_fleet_owner(
  uuid, text, text, jsonb
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_notify_private_owner_attempt(
  uuid, uuid, text
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fn_app_notification_owner_ids(text, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_lifecycle_resolve_driver()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_lifecycle_audit(
  uuid, text, uuid, jsonb
) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_maybe_notify_near_pickup_for_driver(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_process_scheduled_rides_no_driver()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_recalculate_ride_fare(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.simulate_driver_movement()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_notify_fleet_owner(
  uuid, text, text, jsonb
) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_notify_private_owner_attempt(
  uuid, uuid, text
) TO service_role;
