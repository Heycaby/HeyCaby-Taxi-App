-- Restore one public dispatch seeding boundary after later production DDL
-- replaced the booking-mode router with a second copy of the dispatch-v3
-- implementation. Released Rider clients keep both existing signatures.
-- Internal implementations remain present for rollback/compatibility but are
-- no longer callable directly by public API roles.

CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch(
  p_ride_request_id uuid,
  p_batch_size integer DEFAULT NULL,
  p_window_seconds integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_uid uuid := auth.uid();
  v_rider_identity_id uuid;
  v_claim_role text := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(current_setting('request.jwt.claim.role', true), '')
  );
  v_internal boolean;
  v_batch_size integer;
  v_window_seconds integer;
BEGIN
  -- Direct SQL/cron and service-role orchestration are trusted internal
  -- callers. Authenticated app callers must own the ride they ask to seed.
  v_internal := v_claim_role = 'service_role'
    OR (
      v_claim_role IS NULL
      AND session_user NOT IN ('authenticator', 'anon', 'authenticated')
    );

  SELECT *
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF NOT v_internal THEN
    IF v_uid IS NULL THEN
      RETURN json_build_object('ok', false, 'error', 'not_authenticated');
    END IF;

    v_rider_identity_id := public.fn_rider_resolve_identity_id();
    IF v_rider_identity_id IS NULL
       OR v_rider_identity_id IS DISTINCT FROM v_ride.rider_identity_id THEN
      RETURN json_build_object('ok', false, 'error', 'forbidden');
    END IF;
  END IF;

  -- Keep released parameter shapes but cap caller-controlled fan-out and
  -- expiry. Backend configuration still supplies defaults when values are null.
  v_batch_size := CASE
    WHEN p_batch_size IS NULL THEN NULL
    ELSE GREATEST(1, LEAST(p_batch_size, 25))
  END;
  v_window_seconds := CASE
    WHEN p_window_seconds IS NULL THEN NULL
    ELSE GREATEST(5, LEAST(p_window_seconds, 120))
  END;

  IF v_ride.booking_mode = 'terug' THEN
    RETURN public.fn_seed_taxi_terug_matching_batch(
      p_ride_request_id,
      v_batch_size,
      v_window_seconds
    );
  END IF;

  RETURN public.fn_seed_ride_matching_batch_dispatch_v3(
    p_ride_request_id,
    v_batch_size,
    v_window_seconds
  );
END;
$$;

COMMENT ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer, integer) IS
  'Canonical auth-bound booking-mode router. Taxi Terug routes to its matcher; all other modes route to dispatch v3.';

-- Preserve both released signatures. The two-argument overload delegates to
-- the canonical three-argument boundary and therefore inherits its auth check.
REVOKE ALL ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer, integer)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch(uuid, integer)
  TO authenticated, service_role;

-- These are implementation details or scheduled-job commands. Keeping the
-- functions avoids breaking stored dependencies and gives operations a fast
-- rollback path; removing direct Data API execution closes the duplicate
-- command paths without deleting compatibility code.
REVOKE ALL ON FUNCTION public.fn_seed_ride_matching_batch_dispatch_v3(uuid, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch_dispatch_v3(uuid, integer, integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_seed_ride_matching_batch_legacy(uuid, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch_legacy(uuid, integer, integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_seed_taxi_terug_matching_batch(uuid, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_seed_taxi_terug_matching_batch(uuid, integer, integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_advance_ride_matching_waves(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_advance_ride_matching_waves(integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_seed_due_scheduled_ride_matching(integer, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_seed_due_scheduled_ride_matching(integer, integer, integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.fn_accept_invite_diagnostic(uuid, uuid, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_accept_invite_diagnostic(uuid, uuid, integer)
  TO service_role;
