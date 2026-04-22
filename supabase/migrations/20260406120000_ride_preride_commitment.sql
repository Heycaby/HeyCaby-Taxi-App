-- Driver-initiated pre-ride confirmation + optional €1–€5 commitment (Tikkie).
-- Platform tracks state; money moves rider → driver via Tikkie outside HeyCaby.

-- ---------------------------------------------------------------------------
-- Columns on ride_requests
-- ---------------------------------------------------------------------------
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS rider_preride_request_sent_at timestamptz;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS rider_preride_deadline timestamptz;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS rider_preride_confirmed boolean NOT NULL DEFAULT false;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS preride_commitment_fee_euros numeric(4, 2);

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS commitment_fee_tikkie_url text;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS commitment_fee_received boolean NOT NULL DEFAULT false;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS commitment_fee_forfeited_to text;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS driver_preride_released_at timestamptz;

COMMENT ON COLUMN public.ride_requests.rider_preride_request_sent_at IS
  'When the driver sent the pre-ride confirmation (with or without fee request).';
COMMENT ON COLUMN public.ride_requests.rider_preride_deadline IS
  'Rider should confirm before this time (typically sent_at + 15 min).';
COMMENT ON COLUMN public.ride_requests.preride_commitment_fee_euros IS
  'Optional 1–5 EUR commitment; NULL if driver chose confirm-only.';
COMMENT ON COLUMN public.ride_requests.commitment_fee_forfeited_to IS
  'If non-null after dispute/cancel: driver | rider — who keeps the €5 per policy.';
COMMENT ON COLUMN public.ride_requests.driver_preride_released_at IS
  'Driver released the slot after rider missed the pre-ride deadline.';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ride_requests_commitment_fee_forfeited_to_chk'
  ) THEN
    ALTER TABLE public.ride_requests
      ADD CONSTRAINT ride_requests_commitment_fee_forfeited_to_chk
      CHECK (
        commitment_fee_forfeited_to IS NULL
        OR commitment_fee_forfeited_to IN ('driver', 'rider')
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ride_requests_preride_fee_range_chk'
  ) THEN
    ALTER TABLE public.ride_requests
      ADD CONSTRAINT ride_requests_preride_fee_range_chk
      CHECK (
        preride_commitment_fee_euros IS NULL
        OR (
          preride_commitment_fee_euros >= 1
          AND preride_commitment_fee_euros <= 5
        )
      );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Rider reliability tier (simple counts on ride_requests)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_rider_reliability_tier (p_rider_identity_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH s AS (
    SELECT
      count(*) FILTER (WHERE status = 'completed') AS completed,
      count(*) FILTER (WHERE status = 'cancelled') AS cancelled
    FROM ride_requests
    WHERE rider_identity_id IS NOT DISTINCT FROM p_rider_identity_id
  )
  SELECT
    CASE
      WHEN p_rider_identity_id IS NULL THEN 'new'
      WHEN (SELECT completed FROM s) >= 5 THEN 'reliable'
      WHEN (SELECT completed FROM s) = 0
      AND (SELECT cancelled FROM s) >= 2 THEN 'risk'
      WHEN (SELECT completed FROM s) < 3 THEN 'new'
      ELSE 'amber'
    END;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_reliability_bulk (p_ids uuid[])
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT jsonb_object_agg(t.id::text, to_jsonb(t.tier))
      FROM (
        SELECT u.id, public.fn_rider_reliability_tier(u.id) AS tier
        FROM unnest(p_ids) AS u(id)
        WHERE u.id IS NOT NULL
      ) t
    ),
    '{}'::jsonb
  );
$$;

-- ---------------------------------------------------------------------------
-- Driver: send pre-ride confirmation (optional €1–5 + Tikkie URL)
-- Eligible ~16–40 minutes before scheduled_pickup_at, scheduled booking only.
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

  IF v_ride.status NOT IN ('accepted', 'driver_arrived') THEN
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

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- Driver: confirm-only (no fee)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_send_preride_confirmation_no_fee (
  p_ride_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.fn_driver_send_preride_confirmation(
    p_ride_request_id,
    NULL,
    NULL
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Driver: release ride after rider missed deadline (cancels request)
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

  UPDATE ride_requests
  SET
    driver_preride_released_at = now(),
    status = 'cancelled'
  WHERE id = p_ride_request_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- Driver: mark Tikkie paid (honor system; driver confirms receipt)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_driver_mark_commitment_fee_received (
  p_ride_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  SELECT d.id
  INTO v_driver_id
  FROM drivers d
  WHERE d.user_id = auth.uid();

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_driver');
  END IF;

  UPDATE ride_requests
  SET commitment_fee_received = true
  WHERE id = p_ride_request_id
    AND driver_id = v_driver_id
    AND preride_commitment_fee_euros IS NOT NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'update_failed');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- Rider: confirm pre-ride (token matches row)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_rider_confirm_preride (
  p_ride_request_id uuid,
  p_rider_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride record;
BEGIN
  IF p_rider_token IS NULL OR length(trim(p_rider_token)) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_token');
  END IF;

  SELECT *
  INTO v_ride
  FROM ride_requests r
  WHERE r.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.rider_token IS DISTINCT FROM trim(p_rider_token) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'token_mismatch');
  END IF;

  IF v_ride.rider_preride_request_sent_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_request');
  END IF;

  UPDATE ride_requests
  SET rider_preride_confirmed = true
  WHERE id = p_ride_request_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_send_preride_confirmation (uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_send_preride_confirmation_no_fee (uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_release_preride_ride (uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_mark_commitment_fee_received (uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_confirm_preride (uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_confirm_preride (uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_reliability_tier (uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rider_reliability_bulk (uuid[]) TO authenticated;
