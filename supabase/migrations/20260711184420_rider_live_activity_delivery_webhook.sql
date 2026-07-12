DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'rider_agent_webhook_secret'
  ) THEN
    PERFORM vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'rider_agent_webhook_secret',
      'Shared database-to-rider-agent webhook secret'
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.fn_rider_agent_webhook_secret()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, vault
AS $$
  SELECT decrypted_secret
  FROM vault.decrypted_secrets
  WHERE name = 'rider_agent_webhook_secret'
  LIMIT 1
$$;
REVOKE ALL ON FUNCTION public.fn_rider_agent_webhook_secret() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_agent_webhook_secret() TO service_role;

-- Lifecycle notifications were labelled ride_lifecycle while the webhook only
-- forwarded rider_agent rows. Both are rider pushes and belong on one path.
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
  IF NEW.user_type IS DISTINCT FROM 'rider'
     OR NEW.agent NOT IN ('rider_agent', 'ride_lifecycle') THEN
    RETURN NEW;
  END IF;

  SELECT value INTO base_url FROM public.app_config
  WHERE key = 'rider_agent_webhook_url' LIMIT 1;
  SELECT decrypted_secret INTO secret FROM vault.decrypted_secrets
  WHERE name = 'rider_agent_webhook_secret' LIMIT 1;

  IF NULLIF(btrim(base_url), '') IS NULL OR NULLIF(btrim(secret), '') IS NULL THEN
    RAISE WARNING 'rider lifecycle webhook skipped: URL or secret unavailable';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP, 'table', TG_TABLE_NAME,
    'record', to_jsonb(NEW), 'old_record', NULL
  );
  PERFORM net.http_post(
    url := btrim(base_url),
    body := payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', secret
    ),
    timeout_milliseconds := 5000
  );
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_rider_agent_trigger() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_rider_agent_trigger() TO service_role;
