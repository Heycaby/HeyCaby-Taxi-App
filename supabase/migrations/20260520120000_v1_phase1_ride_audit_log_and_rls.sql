-- Phase 1 (M8 + M25): Immutable ride audit log + RLS hardening.
-- Additive only. Does not modify existing RPC behaviour.
-- Applied to HEYCABY-TAXI on 2026-05-20 (migration: v1_phase1_ride_audit_log_and_rls).

-- ---------------------------------------------------------------------------
-- M8: ride_audit_log
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ride_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  event text NOT NULL,
  actor_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT ride_audit_log_event_noun_verb CHECK (position('.' IN event) > 1)
);

CREATE INDEX IF NOT EXISTS idx_ride_audit_log_ride_occurred
  ON public.ride_audit_log (ride_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_ride_audit_log_event
  ON public.ride_audit_log (event);

COMMENT ON TABLE public.ride_audit_log IS
  'Insert-only dispatch and lifecycle audit trail (V1 spec). Corrections are new rows, never updates.';

ALTER TABLE public.ride_audit_log ENABLE ROW LEVEL SECURITY;

-- Append helper (triggers + future RPCs)
CREATE OR REPLACE FUNCTION public.fn_ride_audit_append(
  p_ride_id uuid,
  p_event text,
  p_actor_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_ride_id IS NULL OR p_event IS NULL OR btrim(p_event) = '' THEN
    RETURN;
  END IF;
  INSERT INTO public.ride_audit_log (ride_id, event, actor_id, metadata)
  VALUES (p_ride_id, p_event, p_actor_id, COALESCE(p_metadata, '{}'::jsonb));
END;
$$;

REVOKE ALL ON FUNCTION public.fn_ride_audit_append(uuid, text, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ride_audit_append(uuid, text, uuid, jsonb) TO service_role;

-- ride_requests: create + status transitions
CREATE OR REPLACE FUNCTION public.trg_ride_audit_ride_requests()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
BEGIN
  v_actor := auth.uid();

  IF TG_OP = 'INSERT' THEN
    PERFORM public.fn_ride_audit_append(
      NEW.id,
      'ride.created',
      v_actor,
      jsonb_build_object(
        'status', NEW.status,
        'pickup_city_id', NEW.pickup_city_id,
        'country_code', NEW.country_code
      )
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.fn_ride_audit_append(
      NEW.id,
      'ride.status_changed',
      v_actor,
      jsonb_build_object(
        'from_status', OLD.status,
        'to_status', NEW.status,
        'driver_id', NEW.driver_id
      )
    );

    IF NEW.status = 'assigned' AND OLD.status IS DISTINCT FROM 'assigned' THEN
      PERFORM public.fn_ride_audit_append(
        NEW.id,
        'ride.assigned',
        COALESCE(v_actor, NEW.driver_id),
        jsonb_build_object('driver_id', NEW.driver_id)
      );
    END IF;

    IF NEW.status IN ('completed', 'closed') AND OLD.status IS DISTINCT FROM NEW.status THEN
      PERFORM public.fn_ride_audit_append(
        NEW.id,
        'trip.completed',
        COALESCE(v_actor, NEW.driver_id),
        jsonb_build_object(
          'driver_id', NEW.driver_id,
          'platform_fee_cents', NEW.platform_fee_cents
        )
      );
    END IF;

    IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
      PERFORM public.fn_ride_audit_append(
        NEW.id,
        'ride.cancelled',
        v_actor,
        jsonb_build_object(
          'cancelled_by', NEW.cancelled_by,
          'reason', NEW.cancellation_reason
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ride_audit_ride_requests ON public.ride_requests;
CREATE TRIGGER trg_ride_audit_ride_requests
  AFTER INSERT OR UPDATE OF status ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_ride_audit_ride_requests();

-- ride_request_invites: sent + outcome
CREATE OR REPLACE FUNCTION public.trg_ride_audit_invites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.fn_ride_audit_append(
      NEW.ride_request_id,
      'offer.sent',
      NULL,
      jsonb_build_object(
        'invite_id', NEW.id,
        'driver_id', NEW.driver_id,
        'batch_no', NEW.batch_no,
        'expires_at', NEW.expires_at
      )
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    v_event := CASE NEW.status
      WHEN 'accepted' THEN 'offer.accepted'
      WHEN 'expired' THEN 'offer.expired'
      WHEN 'superseded' THEN 'offer.cancelled'
      ELSE 'offer.status_changed'
    END;

    PERFORM public.fn_ride_audit_append(
      NEW.ride_request_id,
      v_event,
      auth.uid(),
      jsonb_build_object(
        'invite_id', NEW.id,
        'driver_id', NEW.driver_id,
        'from_status', OLD.status,
        'to_status', NEW.status,
        'batch_no', NEW.batch_no
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ride_audit_invites ON public.ride_request_invites;
CREATE TRIGGER trg_ride_audit_invites
  AFTER INSERT OR UPDATE OF status ON public.ride_request_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_ride_audit_invites();

-- RLS: participants + admin read; no client writes
DROP POLICY IF EXISTS ride_audit_log_select_driver ON public.ride_audit_log;
CREATE POLICY ride_audit_log_select_driver
  ON public.ride_audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ride_requests rr
      JOIN public.drivers d ON d.id = rr.driver_id
      WHERE rr.id = ride_audit_log.ride_id
        AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ride_audit_log_select_rider ON public.ride_audit_log;
CREATE POLICY ride_audit_log_select_rider
  ON public.ride_audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ride_requests rr
      WHERE rr.id = ride_audit_log.ride_id
        AND rr.rider_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ride_audit_log_select_rider_identity ON public.ride_audit_log;
CREATE POLICY ride_audit_log_select_rider_identity
  ON public.ride_audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ride_requests rr
      JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
      WHERE rr.id = ride_audit_log.ride_id
        AND ri.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ride_audit_log_select_admin ON public.ride_audit_log;
CREATE POLICY ride_audit_log_select_admin
  ON public.ride_audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- M25: RLS on launch_regions (read-only rollout config for authenticated)
-- ---------------------------------------------------------------------------
ALTER TABLE public.launch_regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS launch_regions_select_authenticated ON public.launch_regions;
CREATE POLICY launch_regions_select_authenticated
  ON public.launch_regions
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Writes: service role / migrations only (no authenticated INSERT/UPDATE/DELETE policies)

-- ---------------------------------------------------------------------------
-- M25: RLS on founding_contract_links (sensitive; no direct client access)
-- ---------------------------------------------------------------------------
ALTER TABLE public.founding_contract_links ENABLE ROW LEVEL SECURITY;

-- No SELECT/INSERT/UPDATE policies for authenticated/anon → deny by default.
-- Edge Functions and service_role bypass RLS.
