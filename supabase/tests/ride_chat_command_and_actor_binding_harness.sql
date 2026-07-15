-- Minimal disposable PostgreSQL harness for ride-chat authority tests.
-- Never run this harness against a shared or production database.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
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

GRANT USAGE ON SCHEMA auth, public TO anon, authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;

CREATE TABLE public.drivers (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE
);

CREATE TABLE public.rider_identities (
  id uuid PRIMARY KEY,
  user_id uuid
);

CREATE TABLE public.rider_sessions (
  session_token text PRIMARY KEY,
  user_id uuid
);

CREATE TABLE public.ride_requests (
  id uuid PRIMARY KEY,
  status text NOT NULL,
  driver_id uuid,
  rider_id uuid,
  rider_identity_id uuid,
  rider_token text
);

CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid NOT NULL UNIQUE,
  driver_id uuid,
  rider_identity_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id uuid,
  sender_type varchar NOT NULL,
  sender_id uuid,
  content text NOT NULL,
  message_type varchar DEFAULT 'text',
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  conversation_id uuid
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY messages_insert_participant
ON public.messages FOR INSERT TO authenticated
WITH CHECK (true);

CREATE TABLE public.ride_chat_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  ride_id uuid NOT NULL,
  blocker_id text NOT NULL,
  blocker_type text NOT NULL,
  blocked_id text NOT NULL,
  blocked_type text NOT NULL,
  CONSTRAINT ride_chat_blocks_ride_blocker_blocked_unique
    UNIQUE (ride_id, blocker_id, blocked_id)
);

CREATE TABLE public.ride_chat_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  ride_id uuid NOT NULL,
  reporter_id text NOT NULL,
  reporter_type text NOT NULL,
  reported_id text NOT NULL,
  reported_type text NOT NULL,
  reason text
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_type text,
  user_id uuid,
  category text,
  data jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE public.ride_audit_log (
  ride_id uuid,
  event text,
  actor_id uuid,
  metadata jsonb,
  actor_type text,
  source text,
  correlation_id uuid
);

CREATE FUNCTION public.fn_ride_audit_append(
  p_ride_id uuid,
  p_event text,
  p_actor_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_actor_type text DEFAULT NULL,
  p_source text DEFAULT NULL,
  p_correlation_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE sql
AS $$
  INSERT INTO public.ride_audit_log (
    ride_id, event, actor_id, metadata, actor_type, source, correlation_id
  ) VALUES (
    p_ride_id, p_event, p_actor_id, p_metadata, p_actor_type, p_source,
    p_correlation_id
  );
$$;

CREATE FUNCTION public.notify_driver_agent_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NEW;
END;
$$;

CREATE TRIGGER driver_agent_on_messages
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.notify_driver_agent_trigger();

CREATE PUBLICATION supabase_realtime FOR TABLE public.messages;

GRANT SELECT ON public.ride_requests, public.drivers,
  public.rider_identities, public.rider_sessions TO authenticated;
GRANT SELECT, INSERT ON public.messages TO authenticated;

INSERT INTO public.drivers (id, user_id) VALUES
  ('00000000-0000-0000-0000-000000000022',
   '00000000-0000-0000-0000-000000000012');
INSERT INTO public.rider_identities (id, user_id) VALUES
  ('00000000-0000-0000-0000-000000000021',
   '00000000-0000-0000-0000-000000000011');
INSERT INTO public.rider_sessions (session_token, user_id) VALUES
  ('rider-session-test', '00000000-0000-0000-0000-000000000011');
INSERT INTO public.ride_requests (
  id, status, driver_id, rider_id, rider_identity_id, rider_token
) VALUES (
  '00000000-0000-0000-0000-000000000031',
  'accepted',
  '00000000-0000-0000-0000-000000000022',
  '00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000021',
  'rider-session-test'
);
INSERT INTO public.conversations (
  id, ride_request_id, driver_id, rider_identity_id
) VALUES (
  '00000000-0000-0000-0000-000000000041',
  '00000000-0000-0000-0000-000000000031',
  '00000000-0000-0000-0000-000000000022',
  '00000000-0000-0000-0000-000000000021'
);

\ir ../migrations/20260714072357_ride_chat_command_and_actor_binding.sql
\ir ../migrations/20260714072951_ride_chat_rls_initplan.sql
\ir ride_chat_command_and_actor_binding_test.sql
