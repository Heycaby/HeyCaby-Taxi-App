-- Keep the requester snapshot internal to the Secure Shift Handover RPC chain.
-- The authenticated app calls the step-up protected handover RPC, not this
-- SECURITY DEFINER helper directly.

REVOKE ALL ON FUNCTION public.fn_driver_shift_handover_requester_snapshot(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_shift_handover_requester_snapshot(uuid)
  TO service_role;
