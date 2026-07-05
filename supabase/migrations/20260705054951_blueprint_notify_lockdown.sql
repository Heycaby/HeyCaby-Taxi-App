-- Lock down fn_ride_event_notify: it is an internal helper used by
-- SECURITY DEFINER lifecycle/swap RPCs. Clients must not be able to
-- forge notifications for other users.
REVOKE EXECUTE ON FUNCTION public.fn_ride_event_notify(text, text, text, text, text, jsonb, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_ride_event_notify(text, text, text, text, text, jsonb, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_ride_event_notify(text, text, text, text, text, jsonb, text) FROM authenticated;

-- anon has no business calling these either (authenticated keeps access).
REVOKE EXECUTE ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_payment_compatible(uuid, text[]) FROM anon;
