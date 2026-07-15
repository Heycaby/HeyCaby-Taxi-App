-- Production history 20260713133943. Ride Operations owns the Rider lifecycle/read projection. Flutter renders
-- this contract and does not reconstruct business state from raw columns.

CREATE OR REPLACE FUNCTION public.fn_rider_payment_self_confirm_delay_seconds()
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT 600;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_payment_self_confirm_delay_seconds()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_payment_self_confirm_delay_seconds()
  TO service_role;

CREATE OR REPLACE FUNCTION public.trg_guard_rider_payment_self_confirm_delay()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.rider_payment_confirmed_at IS NOT DISTINCT FROM OLD.rider_payment_confirmed_at
     OR OLD.driver_payment_confirmed_at IS NOT NULL
     OR auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- The assigned driver may confirm immediately. A Rider can only use the
  -- fallback after the backend-owned delay.
  IF EXISTS (
    SELECT 1
    FROM public.drivers d
    WHERE d.id = OLD.driver_id
      AND d.user_id = auth.uid()
  ) THEN
    RETURN NEW;
  END IF;

  IF OLD.completed_at IS NULL
     OR timezone('utc', now()) < OLD.completed_at + make_interval(
       secs => public.fn_rider_payment_self_confirm_delay_seconds()
     ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'rider_self_confirm_too_early';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_guard_rider_payment_self_confirm_delay()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_rider_payment_self_confirm_delay
  ON public.ride_requests;
CREATE TRIGGER guard_rider_payment_self_confirm_delay
  BEFORE UPDATE OF rider_payment_confirmed_at ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_guard_rider_payment_self_confirm_delay();

CREATE OR REPLACE FUNCTION public.fn_rider_ride_snapshot(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_effective_status text;
  v_provider_status text;
  v_self_confirm_at timestamptz;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'missing_ride_id');
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ride_not_found');
  END IF;

  IF NOT (
    (
      auth.uid() IS NOT NULL
      AND v_ride.rider_identity_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.rider_identities ri
        WHERE ri.id = v_ride.rider_identity_id
          AND ri.user_id = auth.uid()
      )
    )
    OR (
      p_rider_token IS NOT NULL
      AND btrim(p_rider_token) <> ''
      AND v_ride.rider_token = btrim(p_rider_token)
    )
    OR (
      auth.uid() IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.rider_sessions rs
        WHERE rs.user_id = auth.uid()
          AND rs.session_token = v_ride.rider_token
      )
    )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
  END IF;

  v_effective_status := CASE
    WHEN lower(COALESCE(v_ride.payment_status, '')) IN ('confirmed', 'paid')
      THEN 'payment_confirmed'
    WHEN v_ride.status = 'completed' OR v_ride.completed_at IS NOT NULL
      THEN 'completed'
    WHEN v_ride.status = 'in_progress' OR v_ride.started_at IS NOT NULL
      THEN 'in_progress'
    WHEN v_ride.driver_arrived_at IS NOT NULL
      OR v_ride.status IN ('driver_arrived', 'arrived')
      THEN 'driver_arrived'
    WHEN v_ride.near_pickup_notified_at IS NOT NULL
      THEN 'driver_nearby'
    WHEN v_ride.status = 'driver_en_route'
      THEN 'driver_en_route'
    WHEN v_ride.driver_id IS NOT NULL
      OR v_ride.accepted_at IS NOT NULL
      OR v_ride.status IN ('accepted', 'assigned', 'driver_found')
      THEN CASE
        WHEN v_ride.status NOT IN ('', 'pending', 'bidding', 'cancelled', 'canceled')
          THEN v_ride.status
        ELSE 'accepted'
      END
    ELSE COALESCE(NULLIF(v_ride.status, ''), 'pending')
  END;

  v_provider_status := CASE
    WHEN lower(COALESCE(v_ride.payment_status, '')) IN ('confirmed', 'paid')
      THEN 'completed'
    WHEN v_ride.status = 'completed' OR v_ride.completed_at IS NOT NULL
      THEN 'completed'
    WHEN v_ride.status = 'in_progress' OR v_ride.started_at IS NOT NULL
      THEN 'in_progress'
    WHEN v_ride.driver_arrived_at IS NOT NULL
      OR v_ride.status IN ('driver_arrived', 'arrived')
      THEN 'driver_arrived'
    WHEN NULLIF(v_ride.status, '') IS NOT NULL THEN v_ride.status
    WHEN v_ride.driver_id IS NOT NULL THEN 'accepted'
    ELSE ''
  END;

  v_self_confirm_at := CASE
    WHEN v_ride.completed_at IS NOT NULL
      THEN v_ride.completed_at + make_interval(
        secs => public.fn_rider_payment_self_confirm_delay_seconds()
      )
    ELSE NULL
  END;

  RETURN jsonb_build_object(
    'ok', true,
    'contract_version', 1,
    'id', v_ride.id,
    'status', v_ride.status,
    'effective_status', v_effective_status,
    'provider_status', v_provider_status,
    'driver_id', v_ride.driver_id,
    'accepted_at', v_ride.accepted_at,
    'driver_arrived_at', v_ride.driver_arrived_at,
    'near_pickup_notified_at', v_ride.near_pickup_notified_at,
    'started_at', v_ride.started_at,
    'completed_at', v_ride.completed_at,
    'payment_status', v_ride.payment_status,
    'tip_amount_eur', v_ride.tip_amount_eur,
    'driver_payment_confirmed_at', v_ride.driver_payment_confirmed_at,
    'rider_payment_confirmed_at', v_ride.rider_payment_confirmed_at,
    'rider_self_confirm_available_at', v_self_confirm_at,
    'rider_can_self_confirm',
      v_self_confirm_at IS NOT NULL
      AND timezone('utc', now()) >= v_self_confirm_at
      AND v_ride.driver_payment_confirmed_at IS NULL,
    'updated_at', v_ride.updated_at,
    'created_at', v_ride.created_at,
    'expires_at', v_ride.expires_at,
    'scheduled_pickup_at', v_ride.scheduled_pickup_at,
    'pickup_address', v_ride.pickup_address,
    'destination_address', v_ride.destination_address,
    'destination_lat', v_ride.destination_lat,
    'destination_lng', v_ride.destination_lng,
    'booked_destination_address', v_ride.booked_destination_address,
    'booked_destination_lat', v_ride.booked_destination_lat,
    'booked_destination_lng', v_ride.booked_destination_lng,
    'route_stops', v_ride.route_stops,
    'route_revision', v_ride.route_revision,
    'rider_token', v_ride.rider_token,
    'waiting_grace_seconds', v_ride.waiting_grace_seconds,
    'waiting_rate_per_minute', v_ride.waiting_rate_per_minute,
    'chargeable_wait_seconds', v_ride.chargeable_wait_seconds,
    'waiting_fee_cents', v_ride.waiting_fee_cents,
    'waiting_fee_waived', v_ride.waiting_fee_waived,
    'quoted_fare', v_ride.quoted_fare,
    'offered_fare', v_ride.offered_fare,
    'estimated_fare', v_ride.estimated_fare,
    'final_fare', v_ride.final_fare,
    'marketplace_offered_fare', v_ride.marketplace_offered_fare,
    'payment_method', v_ride.payment_method,
    'payment_method_settled', v_ride.payment_method_settled
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_ride_snapshot(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_ride_snapshot(uuid, text)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_rider_ride_snapshot(uuid, text) IS
  'Versioned Rider read projection for lifecycle, payment timing, route, waiting, fare, and deadlines.';

NOTIFY pgrst, 'reload schema';
