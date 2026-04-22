-- Pre-ride follow-ups: back-to-pool release (rematch), chat line on send,
-- forfeiture rules on cancel/complete, rider snapshot RPC (token-safe reads).
-- Policies: see 20260407180001_preride_rls_messages.sql

-- ---------------------------------------------------------------------------
-- Rider: token-scoped JSON snapshot of preride columns (works under strict RLS).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_rider_get_preride_snapshot (
  p_ride_request_id uuid,
  p_rider_token text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_t text;
  v jsonb;
BEGIN
  IF p_rider_token IS NULL OR length(trim(p_rider_token)) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_token');
  END IF;

  v_t := trim(p_rider_token);

  SELECT
    jsonb_build_object(
      'ok', true,
      'rider_preride_request_sent_at', r.rider_preride_request_sent_at,
      'rider_preride_deadline', r.rider_preride_deadline,
      'rider_preride_confirmed', r.rider_preride_confirmed,
      'preride_commitment_fee_euros', r.preride_commitment_fee_euros,
      'commitment_fee_tikkie_url', r.commitment_fee_tikkie_url,
      'commitment_fee_received', r.commitment_fee_received,
      'commitment_fee_forfeited_to', r.commitment_fee_forfeited_to
    )
  INTO v
  FROM ride_requests r
  WHERE r.id = p_ride_request_id
    AND r.rider_token IS NOT DISTINCT FROM v_t;

  IF v IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  RETURN v;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_rider_get_preride_snapshot (uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_get_preride_snapshot (uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Forfeiture: on cancel with commitment received, other party gets fee;
-- clear on completed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_ride_requests_commitment_forfeit_on_status ()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'completed'
     AND OLD.status IS DISTINCT FROM 'completed' THEN
    NEW.commitment_fee_forfeited_to := NULL;
    RETURN NEW;
  END IF;

  IF NEW.status = 'cancelled'
     AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    IF COALESCE(NEW.commitment_fee_received, false) = true
       AND NEW.commitment_fee_forfeited_to IS NULL
       AND NEW.preride_commitment_fee_euros IS NOT NULL THEN
      IF NEW.cancelled_by = 'rider' THEN
        NEW.commitment_fee_forfeited_to := 'driver';
      ELSIF NEW.cancelled_by = 'driver' THEN
        NEW.commitment_fee_forfeited_to := 'rider';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_ride_requests_commitment_forfeit ON public.ride_requests;

CREATE TRIGGER tr_ride_requests_commitment_forfeit
BEFORE UPDATE OF status ON public.ride_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_ride_requests_commitment_forfeit_on_status ();

-- ---------------------------------------------------------------------------
-- Driver: send pre-ride confirmation (+ optional fee) + chat line for rider.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_send_preride_confirmation (
  p_ride_request_id uuid,
  p_fee_euros numeric,
  p_tikkie_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride record;
  v_mins numeric;
  v_msg text;
BEGIN
  SELECT d.id
  INTO v_driver_id
  FROM drivers d
  WHERE d.user_id = auth.uid();

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_driver');
  END IF;

  SELECT *
  INTO v_ride
  FROM ride_requests r
  WHERE r.id = p_ride_request_id
    AND r.driver_id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.booking_mode IS DISTINCT FROM 'scheduled' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_scheduled_mode');
  END IF;

  IF v_ride.scheduled_pickup_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_pickup_time');
  END IF;

  IF v_ride.rider_preride_request_sent_at IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_sent');
  END IF;

  IF v_ride.status NOT IN ('accepted', 'driver_arrived', 'assigned') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_status');
  END IF;

  v_mins := EXTRACT(epoch FROM (v_ride.scheduled_pickup_at - now())) / 60.0;

  IF v_mins < 16 OR v_mins > 40 THEN
    RETURN jsonb_build_object(
      'ok',
      false,
      'error',
      'outside_window',
      'minutes_to_pickup',
      round(v_mins::numeric, 1)
    );
  END IF;

  IF p_fee_euros IS NOT NULL THEN
    IF p_fee_euros < 1 OR p_fee_euros > 5 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'fee_range');
    END IF;
    IF p_tikkie_url IS NULL OR length(trim(p_tikkie_url)) < 12 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'tikkie_required');
    END IF;
  END IF;

  UPDATE ride_requests
  SET
    rider_preride_request_sent_at = now(),
    rider_preride_deadline = now() + interval '15 minutes',
    rider_preride_confirmed = false,
    preride_commitment_fee_euros = p_fee_euros,
    commitment_fee_tikkie_url = CASE
      WHEN p_fee_euros IS NOT NULL THEN nullif(trim(p_tikkie_url), '')
      ELSE NULL
    END,
    commitment_fee_received = false,
    driver_preride_released_at = NULL
  WHERE id = p_ride_request_id;

  v_msg :=
    'Je chauffeur vraagt je om deze geplande rit te bevestigen voor de rit. Open de app en tik op Ik kom.'
    || E'\n\n'
    || 'Your driver asked you to confirm this scheduled ride before pickup. Open the app and tap I''m coming.';

  IF p_fee_euros IS NOT NULL THEN
    v_msg :=
      v_msg
      || E'\n\n'
      || 'Reserveringsbijdrage EUR '
      || trim(to_char(p_fee_euros, 'FM999999990.00'))
      || ' - betaal via Tikkie:'
      || E'\n'
      || nullif(trim(p_tikkie_url), '');
  END IF;

  INSERT INTO public.messages (
    ride_request_id,
    sender_id,
    sender_type,
    content
  )
  VALUES (
    p_ride_request_id,
    auth.uid(),
    'driver',
    v_msg
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- Driver: release slot after missed deadline → back to matching pool (pending).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_release_preride_ride (
  p_ride_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride record;
  v_seed json;
BEGIN
  SELECT d.id
  INTO v_driver_id
  FROM drivers d
  WHERE d.user_id = auth.uid();

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_driver');
  END IF;

  SELECT *
  INTO v_ride
  FROM ride_requests r
  WHERE r.id = p_ride_request_id
    AND r.driver_id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.rider_preride_request_sent_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_preride_request');
  END IF;

  IF v_ride.rider_preride_confirmed IS TRUE THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_confirmed');
  END IF;

  IF v_ride.rider_preride_deadline IS NOT NULL
  AND now() < v_ride.rider_preride_deadline THEN
    RETURN jsonb_build_object('ok', false, 'error', 'deadline_not_passed');
  END IF;

  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending';

  UPDATE ride_requests
  SET
    driver_preride_released_at = now(),
    driver_id = NULL,
    status = 'pending',
    cancelled_at = NULL,
    cancelled_by = NULL,
    cancellation_reason = NULL,
    rider_preride_request_sent_at = NULL,
    rider_preride_deadline = NULL,
    rider_preride_confirmed = false,
    preride_commitment_fee_euros = NULL,
    commitment_fee_tikkie_url = NULL,
    commitment_fee_received = false,
    commitment_fee_forfeited_to = CASE
      WHEN COALESCE(v_ride.commitment_fee_received, false) THEN 'driver'
      ELSE NULL
    END
  WHERE id = p_ride_request_id;

  SELECT public.fn_seed_ride_matching_batch(p_ride_request_id, 4, 30) INTO v_seed;

  RETURN jsonb_build_object(
    'ok', true,
    'matching', to_jsonb(v_seed)
  );
END;
$$;
