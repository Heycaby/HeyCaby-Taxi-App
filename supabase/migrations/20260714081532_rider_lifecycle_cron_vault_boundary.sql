-- Keep the Rider lifecycle dispatcher schedule unchanged while removing its
-- webhook credential from cron.job. The private boundary resolves URL +
-- credential from server-owned configuration at execution time.

CREATE OR REPLACE FUNCTION private.fn_invoke_rider_lifecycle_dispatch(
  p_limit integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, vault, net
AS $$
DECLARE
  v_base_url text;
  v_url text;
  v_secret text;
  v_request_id bigint;
  v_correlation_id uuid := gen_random_uuid();
BEGIN
  SELECT ac.value
  INTO v_base_url
  FROM public.app_config ac
  WHERE ac.key = 'rider_agent_webhook_url'
  LIMIT 1;

  SELECT ds.decrypted_secret
  INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'rider_agent_webhook_secret'
  LIMIT 1;

  IF NULLIF(btrim(v_base_url), '') IS NULL
     OR NULLIF(btrim(v_secret), '') IS NULL THEN
    INSERT INTO private.domain_security_events(
      domain,
      event,
      metadata
    ) VALUES (
      'notifications',
      'rider_lifecycle_dispatch_config_missing',
      jsonb_build_object('correlation_id', v_correlation_id)
    );
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'webhook_config_missing',
      'correlation_id', v_correlation_id
    );
  END IF;

  v_url := regexp_replace(
    btrim(v_base_url),
    '/[^/]+/?$',
    '/rider-lifecycle-dispatch'
  );

  v_request_id := net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object('limit', greatest(1, least(p_limit, 200))),
    timeout_milliseconds := 10000
  );

  RETURN jsonb_build_object(
    'ok', true,
    'request_id', v_request_id,
    'correlation_id', v_correlation_id
  );
END;
$$;

REVOKE ALL ON FUNCTION private.fn_invoke_rider_lifecycle_dispatch(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.fn_invoke_rider_lifecycle_dispatch(integer)
  TO service_role;

COMMENT ON FUNCTION private.fn_invoke_rider_lifecycle_dispatch(integer) IS
  'Vault-backed cron boundary for Rider lifecycle notification delivery; never stores the webhook secret in cron.job.';

DO $migration$
DECLARE
  v_job_id bigint;
BEGIN
  SELECT j.jobid
  INTO v_job_id
  FROM cron.job j
  WHERE j.jobname = 'rider-lifecycle-dispatch-every-20m'
  LIMIT 1;

  IF v_job_id IS NULL THEN
    RAISE EXCEPTION
      'required cron job rider-lifecycle-dispatch-every-20m not found';
  END IF;

  PERFORM cron.alter_job(
    v_job_id,
    command := 'SELECT private.fn_invoke_rider_lifecycle_dispatch(50);'
  );
END;
$migration$;
