-- Live Go API base (AWS HTTPS). App resolves via get_driver_rest_api_base_url; no client-side default.
-- Point api.heycaby.nl DNS to the ALB per backend/aws/PUBLIC_GO_API.md before relying on this URL.

UPDATE public.app_config
SET value = 'https://api.heycaby.nl'
WHERE key = 'driver_rest_api_base_url';

INSERT INTO public.app_config (key, value)
SELECT 'driver_rest_api_base_url', 'https://api.heycaby.nl'
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_config WHERE key = 'driver_rest_api_base_url'
);
