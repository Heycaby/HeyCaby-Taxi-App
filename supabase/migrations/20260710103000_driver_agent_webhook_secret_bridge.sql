-- Service-role-only bridge for driver-agent to verify database webhook calls.
-- The secret remains in Supabase Vault; it is not embedded in SQL or Git.

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

COMMENT ON FUNCTION public.fn_driver_agent_webhook_secret() IS
  'Returns the existing Vault webhook secret to service_role only for driver-agent verification.';
