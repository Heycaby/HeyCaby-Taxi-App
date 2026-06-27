-- Phase F follow-up: explicitly remove PUBLIC execute from SECURITY DEFINER helpers.

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_check_rate_limit(uuid, uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_finalize_queued_for_driver(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_finalize_queued_for_driver(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.trg_shift_handover_ride_finished() FROM PUBLIC;
