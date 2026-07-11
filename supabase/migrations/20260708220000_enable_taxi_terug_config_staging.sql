-- Enable Taxi Terug matching (Phase 1). app_config.value is text JSON.
UPDATE public.app_config
SET value = (
  COALESCE(NULLIF(btrim(value), '')::jsonb, '{}'::jsonb)
  || '{"enabled": true}'::jsonb
)::text
WHERE key = 'terugtaxi_config';
