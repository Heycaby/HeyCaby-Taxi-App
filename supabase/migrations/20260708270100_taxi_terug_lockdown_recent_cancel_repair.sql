-- Repair: ensure fn_taxi_terug_recent_cancel_count is service_role-only (idempotent).

REVOKE ALL ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_recent_cancel_count(uuid) TO service_role;
