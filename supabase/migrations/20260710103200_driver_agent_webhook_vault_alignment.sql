-- Align the existing driver-agent database webhook with Supabase Vault.
-- This migration migrates the existing staging secret without exposing it,
-- then updates the existing sender and service-role verification bridge.

DO $$
DECLARE
  v_existing_secret text;
BEGIN
  SELECT value
  INTO v_existing_secret
  FROM public.app_config
  WHERE key = 'agent_webhook_secret'
  LIMIT 1;

  IF NOT EXISTS (
    SELECT 1
    FROM vault.decrypted_secrets
    WHERE name = 'agent_webhook_secret'
  ) THEN
    IF v_existing_secret IS NULL OR length(trim(v_existing_secret)) < 16 THEN
      RAISE EXCEPTION
        'driver-agent webhook secret is unavailable; refusing to create an unusable webhook contract';
    END IF;

    PERFORM vault.create_secret(
      v_existing_secret,
      'agent_webhook_secret',
      'Shared secret sent by database webhooks to driver-agent',
      NULL
    );
  END IF;

  DELETE FROM public.app_config
  WHERE key = 'agent_webhook_secret';
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_agent_webhook_secret()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, vault
AS $$
  SELECT decrypted_secret
  FROM vault.decrypted_secrets
  WHERE name = 'agent_webhook_secret'
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_agent_webhook_secret() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_driver_agent_webhook_secret() FROM anon;
REVOKE ALL ON FUNCTION public.fn_driver_agent_webhook_secret() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_agent_webhook_secret() TO service_role;

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
  SELECT value
  INTO base_url
  FROM public.app_config
  WHERE key = 'agent_webhook_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO secret
  FROM vault.decrypted_secrets
  WHERE name = 'agent_webhook_secret'
  LIMIT 1;

  IF base_url IS NULL OR length(trim(base_url)) = 0 THEN
    RAISE WARNING 'notify_driver_agent_trigger skipped: missing agent_webhook_url';
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF secret IS NULL OR length(trim(secret)) < 16 THEN
    RAISE WARNING 'notify_driver_agent_trigger skipped: missing webhook secret';
    RETURN COALESCE(NEW, OLD);
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', CASE
      WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)
      ELSE to_jsonb(NEW)
    END,
    'old_record', CASE
      WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD)
      ELSE NULL
    END
  );

  PERFORM net.http_post(
    url := trim(base_url),
    body := payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', secret
    ),
    timeout_milliseconds := 5000
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.notify_driver_agent_trigger() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_driver_agent_trigger() FROM anon;
REVOKE ALL ON FUNCTION public.notify_driver_agent_trigger() FROM authenticated;

COMMENT ON FUNCTION public.fn_driver_agent_webhook_secret() IS
  'Returns the existing Vault webhook secret to service_role only for driver-agent verification.';

COMMENT ON FUNCTION public.notify_driver_agent_trigger() IS
  'Sends existing database webhook events to driver-agent using a Vault-backed shared secret.';
