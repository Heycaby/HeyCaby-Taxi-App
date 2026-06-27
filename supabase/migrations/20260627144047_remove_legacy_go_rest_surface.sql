-- Release hardening: remove the retired Go REST base-url surface.
-- Flutter launch builds now resolve runtime, billing, notifications, and ride
-- lifecycle exclusively through Supabase RPCs and Edge Functions.

DROP FUNCTION IF EXISTS public.get_driver_rest_api_base_url();

DELETE FROM public.app_config
WHERE key = 'driver_rest_api_base_url';
