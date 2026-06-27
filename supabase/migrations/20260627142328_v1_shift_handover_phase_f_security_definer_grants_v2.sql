-- Phase F follow-up: remove explicit app-role execute from internal SECURITY DEFINER helpers.

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_check_rate_limit(uuid, uuid, text) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_finalize_queued_for_driver(uuid) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_shift_handover_ride_finished() FROM anon, authenticated;
