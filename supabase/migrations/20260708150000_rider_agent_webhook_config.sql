-- Rider Agent webhook configuration for rider notifications.
-- This trigger sends rider_agent notifications to the rider-agent Edge Function
-- to deliver FCM pushes to rider devices.

-- Add rider-agent webhook URL to app_config (staging-specific)
INSERT INTO public.app_config (key, value)
VALUES (
  'rider_agent_webhook_url',
  'https://fdavszxncggswuiwggcp.supabase.co/functions/v1/rider-agent'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value;

-- Add rider-agent webhook secret to vault (staging-specific)
DO $$
DECLARE
  v_existing_secret text;
BEGIN
  IF to_regclass('vault.decrypted_secrets') IS NULL THEN
    RAISE WARNING 'rider-agent webhook vault migration skipped: vault.decrypted_secrets unavailable';
    RETURN;
  END IF;

  -- Check if secret already exists
  SELECT decrypted_secret INTO v_existing_secret
  FROM vault.decrypted_secrets
  WHERE name = 'rider_agent_webhook_secret'
  LIMIT 1;

  -- Only create if it doesn't exist (use a default for staging)
  IF v_existing_secret IS NULL THEN
    PERFORM vault.create_secret(
      'rider-agent-staging-secret-change-in-production',
      'rider_agent_webhook_secret',
      'Shared secret sent by database webhooks to rider-agent',
      NULL
    );
  END IF;
END $$;

-- Create trigger function to send rider_agent notifications to rider-agent
CREATE OR REPLACE FUNCTION public.notify_rider_agent_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  payload jsonb;
  base_url text;
  secret text;
BEGIN
  SELECT value INTO base_url
  FROM public.app_config
  WHERE key = 'rider_agent_webhook_url'
  LIMIT 1;

  SELECT decrypted_secret INTO secret
  FROM vault.decrypted_secrets
  WHERE name = 'rider_agent_webhook_secret'
  LIMIT 1;

  IF base_url IS NULL OR length(trim(base_url)) = 0 THEN
    RAISE WARNING 'notify_rider_agent_trigger skipped: missing rider_agent_webhook_url';
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Only send for rider_agent notifications
  IF NEW.agent IS DISTINCT FROM 'rider_agent' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type',       TG_OP,
    'table',      TG_TABLE_NAME,
    'record',     to_jsonb(NEW),
    'old_record', NULL
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

  RETURN NEW;
END;
$$;

-- Create trigger on notifications table
DROP TRIGGER IF EXISTS rider_agent_on_notifications ON public.notifications;

CREATE TRIGGER rider_agent_on_notifications
AFTER INSERT ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.notify_rider_agent_trigger();

COMMENT ON FUNCTION public.notify_rider_agent_trigger() IS
'Sends rider_agent notifications to rider-agent Edge Function for FCM delivery';
