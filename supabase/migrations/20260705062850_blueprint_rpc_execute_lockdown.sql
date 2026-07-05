-- Final lockdown for blueprint helper RPCs.
--
-- Postgres grants EXECUTE to PUBLIC by default for new functions. Revoking
-- anon alone is not enough because anon inherits PUBLIC. These RPCs are app
-- contracts, but they should not be anonymous callable surfaces.

REVOKE EXECUTE ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_payment_compatible(uuid, text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_payment_compatible(uuid, text[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_payment_compatible(uuid, text[]) TO authenticated;
