-- Minimal disposable PostgreSQL harness for internal RPC grant restoration and
-- Driver power-card actor binding. Never run against a shared database.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END;
$$;

CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

CREATE TABLE auth.users (
  id uuid PRIMARY KEY
);

CREATE TABLE public.drivers (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL
);

CREATE TABLE public.driver_power_suggestions (
  id uuid PRIMARY KEY,
  driver_id uuid NOT NULL,
  dismissed_at timestamptz,
  acted_on_at timestamptz
);

CREATE TABLE public.notification_lifecycle_jobs (
  id uuid PRIMARY KEY
);

CREATE TABLE private.domain_security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain text NOT NULL,
  event text NOT NULL,
  actor_user_id uuid,
  object_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE FUNCTION public.check_all_compliance_expiries()
RETURNS TABLE(driver_id uuid, issue text)
LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid, NULL::text WHERE false $$;
CREATE FUNCTION public.expire_stale_auctions()
RETURNS TABLE(expired_request_id uuid, bids_expired bigint)
LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::uuid, 0::bigint WHERE false $$;
CREATE FUNCTION public.expire_stale_favorite_requests()
RETURNS integer LANGUAGE sql SECURITY DEFINER AS $$ SELECT 0 $$;
CREATE FUNCTION public.expire_stale_swaps()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_claim_due_rider_lifecycle_jobs(integer)
RETURNS SETOF public.notification_lifecycle_jobs
LANGUAGE sql SECURITY DEFINER AS $$ SELECT * FROM public.notification_lifecycle_jobs WHERE false $$;
CREATE FUNCTION public.fn_community_cleanup_expired_posts()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_force_offline_for_handover(uuid, text)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_billing_audit_append(uuid, text, uuid, jsonb, uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT $$;
CREATE FUNCTION public.fn_driver_billing_apply_settlement(uuid, integer, text, text, jsonb)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_driver_billing_checkout_intent_by_payment(text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_driver_billing_record_checkout_intent(
  uuid, integer, text, text, text, text, text, jsonb
)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.fn_dismiss_power_card(uuid, uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT false $$;
CREATE FUNCTION public.fn_act_on_power_card(uuid, uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT false $$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  TO PUBLIC, anon, authenticated, service_role;

\ir ../migrations/20260714074731_internal_rpc_grant_and_power_card_hardening.sql
\ir internal_rpc_grant_and_power_card_hardening_test.sql

INSERT INTO auth.users (id) VALUES
  ('00000000-0000-0000-0000-000000000101'),
  ('00000000-0000-0000-0000-000000000102');
INSERT INTO public.drivers (id, user_id) VALUES
  (
    '00000000-0000-0000-0000-000000000111',
    '00000000-0000-0000-0000-000000000101'
  ),
  (
    '00000000-0000-0000-0000-000000000112',
    '00000000-0000-0000-0000-000000000102'
  );
INSERT INTO public.driver_power_suggestions (id, driver_id) VALUES
  (
    '00000000-0000-0000-0000-000000000121',
    '00000000-0000-0000-0000-000000000111'
  ),
  (
    '00000000-0000-0000-0000-000000000122',
    '00000000-0000-0000-0000-000000000112'
  );

SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000101',
  false
);
SET ROLE authenticated;
SELECT public.fn_dismiss_power_card(
  '00000000-0000-0000-0000-000000000121',
  '00000000-0000-0000-0000-000000000111'
);
SELECT public.fn_act_on_power_card(
  '00000000-0000-0000-0000-000000000122',
  '00000000-0000-0000-0000-000000000112'
);
RESET ROLE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_power_suggestions
    WHERE id = '00000000-0000-0000-0000-000000000121'
      AND dismissed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'own power card was not updated';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.driver_power_suggestions
    WHERE id = '00000000-0000-0000-0000-000000000122'
      AND acted_on_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'cross-driver power card was updated';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM private.domain_security_events
    WHERE event = 'power_card_identity_mismatch'
      AND actor_user_id = '00000000-0000-0000-0000-000000000101'
      AND object_id = '00000000-0000-0000-0000-000000000122'
  ) THEN
    RAISE EXCEPTION 'cross-driver denial was not audited';
  END IF;
END;
$$;

SELECT 'power_card_actor_binding_behavior_passed' AS result;
