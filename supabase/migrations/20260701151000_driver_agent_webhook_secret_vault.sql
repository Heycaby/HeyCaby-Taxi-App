-- Move the database webhook sender secret out of app_config and into Supabase
-- Vault. The Edge Function still verifies against AGENT_WEBHOOK_SECRET from
-- Edge Function secrets. This migration avoids embedding the secret in Git or
-- trigger SQL text.

DO $$
DECLARE
  v_existing_app_config_secret text;
BEGIN
  IF to_regclass('vault.decrypted_secrets') IS NULL THEN
    RAISE WARNING 'driver-agent webhook vault migration skipped: vault.decrypted_secrets unavailable';
    RETURN;
  END IF;

  SELECT value
  INTO v_existing_app_config_secret
  FROM public.app_config
  WHERE key = 'agent_webhook_secret'
  LIMIT 1;

  IF v_existing_app_config_secret IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM vault.decrypted_secrets
       WHERE name = 'agent_webhook_secret'
     ) THEN
    PERFORM vault.create_secret(
      v_existing_app_config_secret,
      'agent_webhook_secret',
      'Shared secret sent by database webhooks to driver-agent',
      NULL
    );
  END IF;

  DELETE FROM public.app_config
  WHERE key = 'agent_webhook_secret';
END $$;

CREATE OR REPLACE FUNCTION public.notify_driver_agent_trigger()
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
  WHERE key = 'agent_webhook_url'
  LIMIT 1;

  SELECT decrypted_secret INTO secret
  FROM vault.decrypted_secrets
  WHERE name = 'agent_webhook_secret'
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
