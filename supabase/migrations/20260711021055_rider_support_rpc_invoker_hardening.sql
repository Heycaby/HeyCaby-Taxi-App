-- The support RPCs operate only on rows already protected by tickets RLS.
-- SECURITY INVOKER preserves those policies and avoids unnecessary elevation.
alter function public.fn_rider_support_create_ticket(text, text) security invoker;
alter function public.fn_rider_support_append_message(uuid, text) security invoker;
alter function public.fn_rider_support_resolve_ticket(uuid) security invoker;
