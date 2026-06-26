-- M14A — driver_sessions (Program 2, Presence Foundation).
-- REPO ONLY until explicit production approval. Does NOT touch dispatch/billing/accept.

CREATE TABLE IF NOT EXISTS public.driver_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  device_id text NOT NULL,

  transport_state text NOT NULL DEFAULT 'disconnected',
  presence_state text NOT NULL DEFAULT 'unknown',
  operational_state text NOT NULL DEFAULT 'offline',

  connected_at timestamptz,
  ended_at timestamptz,
  end_reason text,
  last_heartbeat_at timestamptz,
  last_realtime_at timestamptz,
  last_transition_at timestamptz NOT NULL DEFAULT timezone('utc', now()),

  app_version text,
  platform text,
  push_token text,

  is_authoritative boolean NOT NULL DEFAULT true,
  superseded_by_session_id uuid REFERENCES public.driver_sessions(id),
  superseded_at timestamptz,

  state_machine_version integer NOT NULL DEFAULT 1,

  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT driver_sessions_transport_state_check
    CHECK (transport_state IN ('disconnected', 'connected')),
  CONSTRAINT driver_sessions_presence_state_check
    CHECK (presence_state IN ('unknown', 'present', 'stale', 'reconnecting', 'ended')),
  CONSTRAINT driver_sessions_operational_state_check
    CHECK (operational_state IN ('offline', 'available', 'busy', 'paused')),
  CONSTRAINT driver_sessions_platform_check
    CHECK (platform IS NULL OR platform IN ('ios', 'android'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_driver_sessions_authoritative_open
  ON public.driver_sessions (driver_id)
  WHERE is_authoritative = true AND ended_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_driver_sessions_driver_created
  ON public.driver_sessions (driver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_driver_sessions_presence_active
  ON public.driver_sessions (presence_state, last_heartbeat_at DESC NULLS LAST)
  WHERE ended_at IS NULL;

COMMENT ON TABLE public.driver_sessions IS
  'Temporary connectivity sessions (Program 2). Permanent driver identity stays on drivers.';

ALTER TABLE public.driver_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_sessions_driver_select ON public.driver_sessions;
CREATE POLICY driver_sessions_driver_select
  ON public.driver_sessions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = driver_sessions.driver_id AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS driver_sessions_admin_select ON public.driver_sessions;
CREATE POLICY driver_sessions_admin_select
  ON public.driver_sessions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
  );

-- Rollout flag (expose-only until Flutter wires)
INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'connectivity_m14_enabled', 'false'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL'
    AND config_key = 'connectivity_m14_enabled' AND active = true
);

INSERT INTO public.market_config (scope, country_code, config_key, config_value)
SELECT 'country', 'NL', 'connectivity_state_machine_version', '1'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.market_config
  WHERE scope = 'country' AND country_code = 'NL'
    AND config_key = 'connectivity_state_machine_version' AND active = true
);

REVOKE ALL ON TABLE public.driver_sessions FROM PUBLIC;
GRANT SELECT ON TABLE public.driver_sessions TO authenticated, service_role;
