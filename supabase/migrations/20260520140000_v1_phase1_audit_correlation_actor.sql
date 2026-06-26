-- Phase 1.5: Enrich ride_audit_log with actor + correlation (additive).
-- correlation_id groups all events for one ride journey (defaults to ride_id).

ALTER TABLE public.ride_audit_log
  ADD COLUMN IF NOT EXISTS correlation_id uuid,
  ADD COLUMN IF NOT EXISTS actor_type text,
  ADD COLUMN IF NOT EXISTS source text;

COMMENT ON COLUMN public.ride_audit_log.correlation_id IS
  'Groups audit events for one ride flow; defaults to ride_id.';
COMMENT ON COLUMN public.ride_audit_log.actor_type IS
  'rider | driver | system | admin — who caused the event when known.';
COMMENT ON COLUMN public.ride_audit_log.source IS
  'Origin e.g. flutter_rider, flutter_driver, supabase_trigger, edge_function.';

CREATE INDEX IF NOT EXISTS idx_ride_audit_log_correlation
  ON public.ride_audit_log (correlation_id, occurred_at DESC);

-- Replace 4-arg helper with 7-arg version
DROP FUNCTION IF EXISTS public.fn_ride_audit_append(uuid, text, uuid, jsonb);

-- Backfill existing rows (if any)
UPDATE public.ride_audit_log
SET correlation_id = ride_id
WHERE correlation_id IS NULL;

ALTER TABLE public.ride_audit_log
  ALTER COLUMN correlation_id SET DEFAULT NULL;

CREATE OR REPLACE FUNCTION public.fn_ride_audit_append(
  p_ride_id uuid,
  p_event text,
  p_actor_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_actor_type text DEFAULT NULL,
  p_source text DEFAULT NULL,
  p_correlation_id uuid DEFAULT NULL
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
  INSERT INTO public.ride_audit_log (
    ride_id, event, actor_id, metadata,
    actor_type, source, correlation_id
  )
  VALUES (
    p_ride_id,
    p_event,
    p_actor_id,
    COALESCE(p_metadata, '{}'::jsonb),
    NULLIF(btrim(p_actor_type), ''),
    NULLIF(btrim(p_source), ''),
    COALESCE(p_correlation_id, p_ride_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_ride_audit_append(uuid, text, uuid, jsonb, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ride_audit_append(uuid, text, uuid, jsonb, text, text, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.trg_ride_audit_ride_requests()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
  v_actor_type text := 'system';
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = v_actor) THEN
      v_actor_type := 'driver';
    ELSIF EXISTS (SELECT 1 FROM public.rider_identities ri WHERE ri.user_id = v_actor) THEN
      v_actor_type := 'rider';
    ELSIF EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = v_actor) THEN
      v_actor_type := 'admin';
    ELSE
      v_actor_type := 'rider';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    PERFORM public.fn_ride_audit_append(
      NEW.id, 'ride.created', v_actor,
      jsonb_build_object('status', NEW.status, 'pickup_city_id', NEW.pickup_city_id, 'country_code', NEW.country_code),
      v_actor_type, 'supabase_trigger', NEW.id
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.fn_ride_audit_append(
      NEW.id, 'ride.status_changed', v_actor,
      jsonb_build_object('from_status', OLD.status, 'to_status', NEW.status, 'driver_id', NEW.driver_id),
      v_actor_type, 'supabase_trigger', NEW.id
    );

    IF NEW.status = 'assigned' AND OLD.status IS DISTINCT FROM 'assigned' THEN
      PERFORM public.fn_ride_audit_append(
        NEW.id, 'ride.assigned', COALESCE(v_actor, NEW.driver_id),
        jsonb_build_object('driver_id', NEW.driver_id),
        CASE WHEN NEW.driver_id IS NOT NULL THEN 'driver' ELSE v_actor_type END,
        'supabase_trigger', NEW.id
      );
    END IF;

    IF NEW.status IN ('completed', 'closed') AND OLD.status IS DISTINCT FROM NEW.status THEN
      PERFORM public.fn_ride_audit_append(
        NEW.id, 'trip.completed', COALESCE(v_actor, NEW.driver_id),
        jsonb_build_object('driver_id', NEW.driver_id, 'platform_fee_cents', NEW.platform_fee_cents),
        CASE WHEN NEW.driver_id IS NOT NULL THEN 'driver' ELSE v_actor_type END,
        'supabase_trigger', NEW.id
      );
    END IF;

    IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
      PERFORM public.fn_ride_audit_append(
        NEW.id, 'ride.cancelled', v_actor,
        jsonb_build_object('cancelled_by', NEW.cancelled_by, 'reason', NEW.cancellation_reason),
        v_actor_type, 'supabase_trigger', NEW.id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_ride_audit_invites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event text;
  v_actor uuid;
  v_actor_type text := 'system';
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = v_actor AND d.id = NEW.driver_id) THEN
      v_actor_type := 'driver';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    PERFORM public.fn_ride_audit_append(
      NEW.ride_request_id, 'offer.sent', NULL,
      jsonb_build_object('invite_id', NEW.id, 'driver_id', NEW.driver_id, 'batch_no', NEW.batch_no, 'expires_at', NEW.expires_at),
      'system', 'supabase_trigger', NEW.ride_request_id
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
      NEW.ride_request_id, v_event, v_actor,
      jsonb_build_object('invite_id', NEW.id, 'driver_id', NEW.driver_id, 'from_status', OLD.status, 'to_status', NEW.status, 'batch_no', NEW.batch_no),
      CASE NEW.status WHEN 'accepted' THEN 'driver' ELSE COALESCE(v_actor_type, 'system') END,
      'supabase_trigger', NEW.ride_request_id
    );
  END IF;

  RETURN NEW;
END;
$$;
