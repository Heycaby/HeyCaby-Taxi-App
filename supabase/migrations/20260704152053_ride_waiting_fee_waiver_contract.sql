-- Ride waiting-fee contract.
--
-- Product rule:
--   Driver taps "arrived" -> rider gets a 2-minute grace window.
--   After grace, waiting is charged from the driver's active waiting tariff.
--   Driver may waive the waiting fee before the ride is completed.
--
-- This migration is additive and then redefines the existing lifecycle RPCs so
-- the waiting state is owned by the same backend transition that owns ride state.

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS waiting_grace_seconds integer NOT NULL DEFAULT 120,
  ADD COLUMN IF NOT EXISTS waiting_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS waiting_rate_per_minute numeric(10, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS chargeable_wait_seconds integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS waiting_fee_cents integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS waiting_fee_waived boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS waiting_fee_waived_at timestamptz,
  ADD COLUMN IF NOT EXISTS waiting_fee_waived_by uuid REFERENCES public.drivers(id),
  ADD COLUMN IF NOT EXISTS waiting_fee_waive_reason text;

ALTER TABLE public.ride_requests
  DROP CONSTRAINT IF EXISTS ride_requests_waiting_grace_seconds_chk,
  DROP CONSTRAINT IF EXISTS ride_requests_waiting_rate_per_minute_chk,
  DROP CONSTRAINT IF EXISTS ride_requests_chargeable_wait_seconds_chk,
  DROP CONSTRAINT IF EXISTS ride_requests_waiting_fee_cents_chk;

ALTER TABLE public.ride_requests
  ADD CONSTRAINT ride_requests_waiting_grace_seconds_chk
    CHECK (waiting_grace_seconds BETWEEN 0 AND 3600),
  ADD CONSTRAINT ride_requests_waiting_rate_per_minute_chk
    CHECK (waiting_rate_per_minute >= 0),
  ADD CONSTRAINT ride_requests_chargeable_wait_seconds_chk
    CHECK (chargeable_wait_seconds >= 0),
  ADD CONSTRAINT ride_requests_waiting_fee_cents_chk
    CHECK (waiting_fee_cents >= 0);

COMMENT ON COLUMN public.ride_requests.waiting_grace_seconds IS
  'Free pickup waiting window after driver_arrived_at. Current launch default: 120 seconds.';
COMMENT ON COLUMN public.ride_requests.waiting_started_at IS
  'Timestamp at which chargeable waiting begins: driver_arrived_at + waiting_grace_seconds.';
COMMENT ON COLUMN public.ride_requests.waiting_rate_per_minute IS
  'Immutable snapshot of the driver waiting tariff in EUR/minute at arrival time.';
COMMENT ON COLUMN public.ride_requests.chargeable_wait_seconds IS
  'Frozen chargeable wait duration, computed when the trip starts.';
COMMENT ON COLUMN public.ride_requests.waiting_fee_cents IS
  'Frozen waiting fee in cents. Set to 0 when waived.';
COMMENT ON COLUMN public.ride_requests.waiting_fee_waived IS
  'True when the driver has waived the waiting fee for this ride.';

-- ---------------------------------------------------------------------------
-- Arrived: accepted -> driver_arrived (+ waiting grace starts)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_arrived(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_waiting_rate numeric(10, 2);
  v_grace_seconds int := 120;
  v_now timestamptz := timezone('utc', now());
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT COALESCE(d.waiting_time_rate_per_min, rp.waiting_rate, 0)::numeric(10, 2)
  INTO v_waiting_rate
  FROM public.drivers d
  LEFT JOIN public.driver_rate_profiles rp
    ON rp.driver_id = d.id
   AND rp.is_active = true
  WHERE d.id = v_driver_id
  LIMIT 1;

  SELECT COALESCE(NULLIF(rr.waiting_grace_seconds, 0), 120)
  INTO v_grace_seconds
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'accepted'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'driver_arrived',
    driver_arrived_at = v_now,
    waiting_grace_seconds = v_grace_seconds,
    waiting_started_at = v_now + (v_grace_seconds::text || ' seconds')::interval,
    waiting_rate_per_minute = COALESCE(v_waiting_rate, 0),
    chargeable_wait_seconds = 0,
    waiting_fee_cents = 0,
    waiting_fee_waived = false,
    waiting_fee_waived_at = NULL,
    waiting_fee_waived_by = NULL,
    waiting_fee_waive_reason = NULL,
    updated_at = v_now
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'accepted';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.arrived',
    v_driver_id,
    jsonb_build_object(
      'status', 'driver_arrived',
      'waiting_grace_seconds', v_grace_seconds,
      'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
    )
  );
  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'waiting.grace_started',
    v_driver_id,
    jsonb_build_object(
      'grace_seconds', v_grace_seconds,
      'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
    )
  );

  RETURN json_build_object(
    'ok', true,
    'status', 'driver_arrived',
    'ride_id', p_ride_request_id,
    'waiting_grace_seconds', v_grace_seconds,
    'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_arrived(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_arrived(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Start: driver_arrived -> in_progress (+ waiting fee freezes)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_ride_start(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_now timestamptz := timezone('utc', now());
  v_chargeable_seconds int := 0;
  v_waiting_fee_cents int := 0;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
  FOR UPDATE;

  IF v_ride.id IS NULL OR v_ride.status <> 'driver_arrived' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  IF v_ride.driver_arrived_at IS NOT NULL THEN
    v_chargeable_seconds := GREATEST(
      0,
      FLOOR(EXTRACT(EPOCH FROM (v_now - v_ride.driver_arrived_at)))::int
        - COALESCE(v_ride.waiting_grace_seconds, 120)
    );
  END IF;

  IF COALESCE(v_ride.waiting_fee_waived, false) THEN
    v_waiting_fee_cents := 0;
  ELSE
    v_waiting_fee_cents := GREATEST(
      0,
      ROUND((v_chargeable_seconds::numeric / 60) * COALESCE(v_ride.waiting_rate_per_minute, 0) * 100)::int
    );
  END IF;

  UPDATE public.ride_requests rr
  SET
    status = 'in_progress',
    started_at = v_now,
    chargeable_wait_seconds = v_chargeable_seconds,
    waiting_fee_cents = v_waiting_fee_cents,
    updated_at = v_now
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'driver_arrived';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.started',
    v_driver_id,
    jsonb_build_object(
      'status', 'in_progress',
      'chargeable_wait_seconds', v_chargeable_seconds,
      'waiting_fee_cents', v_waiting_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );
  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'waiting.fee_frozen',
    v_driver_id,
    jsonb_build_object(
      'chargeable_wait_seconds', v_chargeable_seconds,
      'waiting_rate_per_minute', COALESCE(v_ride.waiting_rate_per_minute, 0),
      'waiting_fee_cents', v_waiting_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  RETURN json_build_object(
    'ok', true,
    'status', 'in_progress',
    'ride_id', p_ride_request_id,
    'chargeable_wait_seconds', v_chargeable_seconds,
    'waiting_fee_cents', v_waiting_fee_cents,
    'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_ride_start(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_ride_start(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Driver waiver: remove waiting charge and notify rider immediately.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_driver_waive_waiting_fee(
  p_ride_request_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride public.ride_requests%ROWTYPE;
  v_now timestamptz := timezone('utc', now());
  v_previous_fee_cents int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status NOT IN ('driver_arrived', 'in_progress') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'waiver_not_allowed_for_status', 'status', v_ride.status);
  END IF;

  v_previous_fee_cents := COALESCE(v_ride.waiting_fee_cents, 0);

  UPDATE public.ride_requests rr
  SET
    waiting_fee_waived = true,
    waiting_fee_waived_at = v_now,
    waiting_fee_waived_by = v_driver_id,
    waiting_fee_waive_reason = NULLIF(btrim(COALESCE(p_reason, '')), ''),
    waiting_fee_cents = 0,
    updated_at = v_now
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id;

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'waiting.fee_waived',
    v_driver_id,
    jsonb_build_object(
      'previous_waiting_fee_cents', v_previous_fee_cents,
      'reason', NULLIF(btrim(COALESCE(p_reason, '')), '')
    )
  );

  IF v_ride.rider_identity_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_type,
      user_id,
      agent,
      category,
      title,
      body,
      data,
      priority,
      channel
    )
    VALUES (
      'rider',
      v_ride.rider_identity_id::text,
      'ride_waiting',
      'waiting_fee_waived',
      'Waiting fee waived',
      'Your driver waived the waiting fee for this ride.',
      jsonb_build_object(
        'ride_request_id', p_ride_request_id,
        'screen', 'active',
        'notification_type', 'waiting_fee_waived',
        'previous_waiting_fee_cents', v_previous_fee_cents
      ),
      'high',
      'both'
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'waiting_fee_waived', true,
    'previous_waiting_fee_cents', v_previous_fee_cents,
    'waiting_fee_cents', 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) IS
  'Driver-only RPC that waives frozen/active waiting charges and notifies the rider.';

-- ---------------------------------------------------------------------------
-- Rider receipt: expose waiting-fee breakdown in the expected total.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_rider_receipt_for_ride(p_ride_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_receipt public.receipts%ROWTYPE;
  v_base_expected numeric;
  v_waiting_fee numeric;
  v_expected numeric;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND EXISTS (
        SELECT 1
        FROM public.rider_identities ri
        WHERE ri.id = rr.rider_identity_id
          AND ri.user_id = auth.uid()
      )
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  SELECT * INTO v_receipt
  FROM public.receipts r
  WHERE r.ride_request_id = p_ride_request_id
  ORDER BY r.issued_at DESC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_receipt');
  END IF;

  v_base_expected := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare
  );
  v_waiting_fee := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;
  v_expected := CASE
    WHEN v_base_expected IS NULL THEN NULL
    ELSE v_base_expected + v_waiting_fee
  END;

  RETURN jsonb_build_object(
    'ok', true,
    'ride_request_id', p_ride_request_id,
    'receipt_id', v_receipt.receipt_id,
    'base_expected_amount', v_base_expected,
    'waiting_fee_amount', v_waiting_fee,
    'waiting_fee_cents', CASE
      WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
      ELSE COALESCE(v_ride.waiting_fee_cents, 0)
    END,
    'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false),
    'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
    'expected_amount', v_expected,
    'paid_amount', v_receipt.amount,
    'payment_method', COALESCE(NULLIF(btrim(v_ride.payment_method), ''), 'cash'),
    'note', v_receipt.notes,
    'currency', COALESCE(NULLIF(btrim(v_receipt.currency), ''), 'EUR'),
    'issued_at', v_receipt.issued_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_receipt_for_ride(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_receipt_for_ride(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_receipt_for_ride(uuid) IS
  'Rider receipt payload including waiting-fee breakdown and waiver state.';
