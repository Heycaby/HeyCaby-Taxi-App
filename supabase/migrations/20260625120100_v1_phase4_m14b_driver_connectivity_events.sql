-- M14B — driver_connectivity_events (immutable event log). REPO ONLY.

CREATE TABLE IF NOT EXISTS public.driver_connectivity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  event_version integer NOT NULL DEFAULT 1,
  state_machine_version integer NOT NULL DEFAULT 1,
  session_id uuid REFERENCES public.driver_sessions(id) ON DELETE SET NULL,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  layer text NOT NULL,
  from_state jsonb,
  to_state jsonb NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  correlation_id uuid,

  CONSTRAINT driver_connectivity_events_type_check
    CHECK (event_type LIKE 'connectivity.%'),
  CONSTRAINT driver_connectivity_events_layer_check
    CHECK (layer IN ('transport', 'presence', 'operational', 'session')),
  CONSTRAINT driver_connectivity_events_event_version_check
    CHECK (event_version >= 1),
  CONSTRAINT driver_connectivity_events_sm_version_check
    CHECK (state_machine_version >= 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_driver_connectivity_events_event_id
  ON public.driver_connectivity_events (event_id);

CREATE INDEX IF NOT EXISTS idx_connectivity_events_driver_time
  ON public.driver_connectivity_events (driver_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_connectivity_events_session_time
  ON public.driver_connectivity_events (session_id, occurred_at DESC)
  WHERE session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_connectivity_events_type_time
  ON public.driver_connectivity_events (event_type, occurred_at DESC);

COMMENT ON TABLE public.driver_connectivity_events IS
  'Append-only connectivity events. State on driver_sessions is derived from these.';

COMMENT ON COLUMN public.driver_connectivity_events.event_id IS
  'Globally unique id for deduplication, tracing, and replay (client or server assigned).';

ALTER TABLE public.driver_connectivity_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_connectivity_events_driver_select ON public.driver_connectivity_events;
CREATE POLICY driver_connectivity_events_driver_select
  ON public.driver_connectivity_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = driver_connectivity_events.driver_id AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS driver_connectivity_events_admin_select ON public.driver_connectivity_events;
CREATE POLICY driver_connectivity_events_admin_select
  ON public.driver_connectivity_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
  );

REVOKE ALL ON TABLE public.driver_connectivity_events FROM PUBLIC;
GRANT SELECT ON TABLE public.driver_connectivity_events TO authenticated, service_role;
