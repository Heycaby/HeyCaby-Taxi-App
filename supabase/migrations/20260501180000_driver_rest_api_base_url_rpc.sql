-- Single source of truth for the Flutter driver Go REST base URL (no app rebuild to change infra).
-- After deploy, set the live URL once in Supabase SQL Editor or migration:
--   UPDATE public.app_config SET value = 'https://your-go-alb-or-gateway.example.com'
--   WHERE key = 'driver_rest_api_base_url';
--
-- SECURITY DEFINER: reads app_config regardless of RLS on the table for anon clients.

CREATE OR REPLACE FUNCTION public.get_driver_rest_api_base_url()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NULLIF(btrim(value), '')
  FROM public.app_config
  WHERE key = 'driver_rest_api_base_url'
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_driver_rest_api_base_url() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_driver_rest_api_base_url() TO anon, authenticated;

-- Seed a row so RPC returns a value before ops pastes the real Go URL (still override via UPDATE).
INSERT INTO public.app_config (key, value)
SELECT 'driver_rest_api_base_url', 'https://api.heycaby.nl'
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_config WHERE key = 'driver_rest_api_base_url'
);
