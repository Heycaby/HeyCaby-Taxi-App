-- Immutable cohort: one server transaction snapshots at most five drivers.
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS dispatch_cohort_locked_at timestamptz,
  ADD COLUMN IF NOT EXISTS dispatch_cohort_txid bigint;

CREATE OR REPLACE FUNCTION public.trg_set_instant_dispatch_expiry()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'pending'
     AND COALESCE(NEW.is_scheduled, false) = false
     AND NEW.scheduled_pickup_at IS NULL
  THEN
    NEW.expires_at := COALESCE(
      NEW.expires_at,
      timezone('utc', now()) + interval '30 seconds'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_instant_dispatch_expiry
  ON public.ride_requests;
CREATE TRIGGER trg_set_instant_dispatch_expiry
  BEFORE INSERT ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_set_instant_dispatch_expiry();

CREATE OR REPLACE FUNCTION public.trg_lock_dispatch_invite_cohort()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_count integer;
  v_txid bigint := txid_current();
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = NEW.ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.status <> 'pending' THEN
    RETURN NULL;
  END IF;
  IF v_ride.expires_at IS NOT NULL AND v_ride.expires_at <= now() THEN
    RETURN NULL;
  END IF;

  IF v_ride.dispatch_cohort_txid IS NULL THEN
    UPDATE public.ride_requests
    SET dispatch_cohort_txid = v_txid,
        dispatch_cohort_locked_at = timezone('utc', now()),
        expires_at = COALESCE(expires_at, NEW.expires_at)
    WHERE id = NEW.ride_request_id;
  ELSIF v_ride.dispatch_cohort_txid <> v_txid THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.ride_request_invites
  WHERE ride_request_id = NEW.ride_request_id;

  IF v_count >= 5 THEN
    RETURN NULL;
  END IF;

  NEW.expires_at := LEAST(
    NEW.expires_at,
    COALESCE(v_ride.expires_at, NEW.expires_at)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lock_dispatch_invite_cohort
  ON public.ride_request_invites;
CREATE TRIGGER trg_lock_dispatch_invite_cohort
  BEFORE INSERT ON public.ride_request_invites
  FOR EACH ROW EXECUTE FUNCTION public.trg_lock_dispatch_invite_cohort();

-- Going online never adds a driver to an existing attempt.
CREATE OR REPLACE FUNCTION public.fn_dispatch_recheck_pending_on_driver_online(
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'ok', true, 'skipped', true, 'reason', 'immutable_dispatch_cohort'
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_dispatch_try_late_join_invite(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'ok', false, 'invited', false, 'reason', 'immutable_dispatch_cohort'
  );
$$;

-- Acceptance can validate only; it must never create or refresh an invite.
CREATE OR REPLACE FUNCTION public.fn_ensure_driver_ride_invite(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = p_driver_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  );
$$;

CREATE OR REPLACE FUNCTION public.trg_require_live_cohort_invite_on_accept()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    IF NEW.driver_id IS NULL OR NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = NEW.id
        AND i.driver_id = NEW.driver_id
        AND i.status = 'pending'
        AND i.expires_at > now()
    ) THEN
      RAISE EXCEPTION 'ride_invite_expired';
    END IF;
    IF OLD.expires_at IS NOT NULL AND OLD.expires_at <= now() THEN
      RAISE EXCEPTION 'ride_request_expired';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_require_live_cohort_invite_on_accept
  ON public.ride_requests;
CREATE TRIGGER trg_require_live_cohort_invite_on_accept
  BEFORE UPDATE OF status, driver_id ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_require_live_cohort_invite_on_accept();

-- Expire stale invitations immediately on any read-side maintenance call.
CREATE OR REPLACE FUNCTION public.fn_expire_stale_ride_invites()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.ride_requests rr
  SET status = 'cancelled',
      cancelled_at = COALESCE(rr.cancelled_at, timezone('utc', now())),
      cancelled_by = COALESCE(rr.cancelled_by, 'system'),
      cancellation_reason = COALESCE(rr.cancellation_reason, 'dispatch_expired'),
      updated_at = timezone('utc', now())
  WHERE rr.status = 'pending'
    AND COALESCE(rr.is_scheduled, false) = false
    AND rr.scheduled_pickup_at IS NULL
    AND COALESCE(rr.expires_at, rr.created_at + interval '30 seconds') <= now();

  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.status = 'pending'
    AND (
      i.expires_at <= now()
      OR EXISTS (
        SELECT 1 FROM public.ride_requests rr
        WHERE rr.id = i.ride_request_id
          AND (rr.status <> 'pending' OR (rr.expires_at IS NOT NULL AND rr.expires_at <= now()))
      )
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Remove the historical requests that caused old calls to be reissued.
UPDATE public.ride_requests rr
SET status = 'cancelled',
    cancelled_at = COALESCE(rr.cancelled_at, timezone('utc', now())),
    cancelled_by = COALESCE(rr.cancelled_by, 'system'),
    cancellation_reason = COALESCE(rr.cancellation_reason, 'dispatch_expired'),
    updated_at = timezone('utc', now())
WHERE rr.status = 'pending'
  AND COALESCE(rr.is_scheduled, false) = false
  AND rr.scheduled_pickup_at IS NULL
  AND COALESCE(rr.expires_at, rr.created_at + interval '30 seconds') <= now();

UPDATE public.ride_request_invites i
SET status = 'expired'
WHERE i.status = 'pending'
  AND (
    i.expires_at <= now()
    OR EXISTS (
      SELECT 1 FROM public.ride_requests rr
      WHERE rr.id = i.ride_request_id AND rr.status <> 'pending'
    )
  );

REVOKE ALL ON FUNCTION public.trg_lock_dispatch_invite_cohort() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_set_instant_dispatch_expiry() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_require_live_cohort_invite_on_accept() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_dispatch_recheck_pending_on_driver_online(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_dispatch_try_late_join_invite(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_ensure_driver_ride_invite(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_expire_stale_ride_invites() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_expire_stale_ride_invites() TO service_role;
REVOKE ALL ON FUNCTION public.fn_driver_accept_ride_invite(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_accept_ride_invite(uuid) TO authenticated, service_role;
