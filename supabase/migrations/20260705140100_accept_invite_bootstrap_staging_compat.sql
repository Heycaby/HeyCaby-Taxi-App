-- Staging compatibility: legacy schema without SDA fn_dispatch_* helpers.
-- Apply on HeyCaby Staging (fdavszxncggswuiwggcp) when SDA v1 is not deployed yet.
-- Production with SDA uses 20260705140000 instead (or both — this replaces fn_ensure with inline checks).

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
  v_d public.drivers%ROWTYPE;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND OR v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN false;
  END IF;

  IF v_ride.pickup_coords IS NULL THEN
    RETURN false;
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

  INSERT INTO public.ride_request_invites (
    ride_request_id, driver_id, batch_no, invited_at, expires_at, status
  )
  VALUES (
    p_ride_request_id,
    p_driver_id,
    0,
    now(),
    now() + make_interval(secs => v_grace),
    'pending'
  )
  ON CONFLICT (ride_request_id, driver_id) DO UPDATE
    SET status = 'pending',
        expires_at = EXCLUDED.expires_at,
        invited_at = now()
  WHERE public.ride_request_invites.status <> 'accepted';

  RETURN true;
END;
$$;
