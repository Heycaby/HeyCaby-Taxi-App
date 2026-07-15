-- Taxi Terug rider posts: 1h open search, browse accept bootstrap, no 5-driver cohort cap.

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
    IF NEW.booking_mode::text = 'terug' THEN
      NEW.expires_at := COALESCE(
        NEW.expires_at,
        timezone('utc', now()) + interval '1 hour'
      );
    ELSE
      NEW.expires_at := COALESCE(
        NEW.expires_at,
        timezone('utc', now()) + interval '30 seconds'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

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

  -- Rider-posted Taxi Terug is an open marketplace (browse + accept).
  IF v_ride.booking_mode::text = 'terug' THEN
    RETURN NEW;
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

CREATE OR REPLACE FUNCTION public.fn_ensure_driver_ride_invite(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_grace int := 30;
  v_window_seconds int := 3600;
  v_d public.drivers%ROWTYPE;
  v_cfg jsonb;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND OR v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN false;
  END IF;

  -- Instant / scheduled dispatch: invite must already exist (immutable cohort).
  IF v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = p_ride_request_id
        AND i.driver_id = p_driver_id
        AND i.status = 'pending'
        AND i.expires_at > now()
    );
  END IF;

  IF v_ride.pickup_coords IS NULL THEN
    RETURN false;
  END IF;

  IF to_regprocedure('public.fn_dispatch_config()') IS NOT NULL THEN
    v_grace := COALESCE(
      (public.fn_dispatch_config()->>'min_driver_accept_window_seconds')::int,
      30
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.driver_id = p_driver_id
      AND i.status IN ('pending', 'expired', 'wave_expired')
      AND i.expires_at > now() - make_interval(secs => v_grace)
  ) THEN
    RETURN true;
  END IF;

  SELECT * INTO v_d FROM public.drivers d WHERE d.id = p_driver_id;
  IF NOT FOUND OR v_d.status IS DISTINCT FROM 'available' THEN
    RETURN false;
  END IF;

  IF COALESCE((public.fn_driver_can_accept_rides(p_driver_id)->>'allowed')::boolean, false) = false THEN
    RETURN false;
  END IF;

  IF NOT public.fn_payment_compatible(p_driver_id, v_ride.payment_methods) THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_locations dl
    WHERE dl.driver_id = p_driver_id
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - interval '5 minutes'
  ) THEN
    RETURN false;
  END IF;

  v_cfg := public.fn_taxi_terug_config();
  v_window_seconds := GREATEST(
    COALESCE((v_cfg->>'invite_window_seconds')::int, 30),
    3600
  );

  INSERT INTO public.ride_request_invites (
    ride_request_id, driver_id, batch_no, invited_at, expires_at, status
  )
  VALUES (
    p_ride_request_id,
    p_driver_id,
    0,
    now(),
    now() + make_interval(secs => v_window_seconds),
    'pending'
  )
  ON CONFLICT (ride_request_id, driver_id) DO UPDATE
    SET status = 'pending',
        expires_at = EXCLUDED.expires_at,
        invited_at = now()
  WHERE public.ride_request_invites.status NOT IN ('accepted', 'superseded');

  RETURN true;
END;
$$;

COMMENT ON FUNCTION public.fn_ensure_driver_ride_invite(uuid, uuid) IS
  'Instant rides: pending invite must exist. Terug rider posts: bootstrap invite on browse accept.';
