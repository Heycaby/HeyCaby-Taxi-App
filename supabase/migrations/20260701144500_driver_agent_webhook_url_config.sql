-- Keep database webhooks environment-specific without embedding secrets.
-- Production default is checked in; staging/branches should override the
-- app_config value to their own project Edge Function URL.
-- Do not replace this production URL with the staging project URL when
-- promoting migrations to production.

INSERT INTO public.app_config (key, value)
VALUES (
  'agent_webhook_url',
  'https://fvrprxguoternoxnyhoj.supabase.co/functions/v1/driver-agent'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value;

CREATE OR REPLACE FUNCTION public.notify_driver_agent_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payload jsonb;
  base_url text;
  secret text;
BEGIN
  SELECT value INTO base_url
  FROM public.app_config
  WHERE key = 'agent_webhook_url'
  LIMIT 1;

  SELECT value INTO secret
  FROM public.app_config
  WHERE key = 'agent_webhook_secret'
  LIMIT 1;

  IF base_url IS NULL OR length(trim(base_url)) = 0 THEN
    RAISE WARNING 'notify_driver_agent_trigger skipped: missing agent_webhook_url';
    RETURN COALESCE(NEW, OLD);
  END IF;

  payload := jsonb_build_object(
    'type',       TG_OP,
    'table',      TG_TABLE_NAME,
    'record',     CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END,
    'old_record', CASE WHEN TG_OP = 'UPDATE'  THEN to_jsonb(OLD) ELSE NULL END
  );

  PERFORM net.http_post(
    url := trim(base_url),
    body := payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', COALESCE(secret, '')
    ),
    timeout_milliseconds := 5000
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;
