-- Ride flow audit fixes (staging): notify resolver, arrived notify restore,
-- payment notifications, near-pickup marker, rider payment claim timestamp.

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS near_pickup_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS payment_claimed_by_rider_at timestamptz;

COMMENT ON COLUMN public.ride_requests.near_pickup_notified_at IS
  'Set once when rider is notified driver is ~1 km from pickup.';
COMMENT ON COLUMN public.ride_requests.payment_claimed_by_rider_at IS
  'Rider self-confirm after timeout; weaker than driver_payment_confirmed_at.';

-- Backfill rider_identity_id from session / push device when possible.
CREATE OR REPLACE FUNCTION public.fn_ensure_ride_rider_identity_for_notify(p_ride_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_identity_id uuid;
  v_user_id uuid;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_ride.rider_identity_id IS NOT NULL THEN
    RETURN v_ride.rider_identity_id;
  END IF;

  IF v_ride.rider_token IS NOT NULL AND btrim(v_ride.rider_token) <> '' THEN
    SELECT rs.user_id INTO v_user_id
    FROM public.rider_sessions rs
    WHERE rs.session_token = btrim(v_ride.rider_token)
    LIMIT 1;

    IF v_user_id IS NOT NULL THEN
      SELECT ri.id INTO v_identity_id
      FROM public.rider_identities ri
      WHERE ri.user_id = v_user_id
      ORDER BY ri.created_at DESC
      LIMIT 1;

      IF v_identity_id IS NULL THEN
        SELECT pd.rider_identity_id INTO v_identity_id
        FROM public.push_devices pd
        WHERE pd.auth_user_id = v_user_id
          AND pd.app_role = 'rider'
          AND pd.rider_identity_id IS NOT NULL
        ORDER BY pd.updated_at DESC NULLS LAST
        LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF v_identity_id IS NOT NULL THEN
    UPDATE public.ride_requests
    SET rider_identity_id = v_identity_id,
        updated_at = timezone('utc', now())
    WHERE id = p_ride_id
      AND rider_identity_id IS NULL;
    RETURN v_identity_id;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_resolve_ride_rider_notify_target(p_ride_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_identity uuid;
BEGIN
  v_identity := public.fn_ensure_ride_rider_identity_for_notify(p_ride_id);

  SELECT * INTO v_ride FROM public.ride_requests WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN COALESCE(
    v_identity::text,
    v_ride.rider_identity_id::text,
    v_ride.rider_id::text
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_ride_notify_rider(
  p_ride_id uuid,
  p_category text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_priority text DEFAULT 'high'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target text;
  v_token text;
  v_payload jsonb;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_target := public.fn_resolve_ride_rider_notify_target(p_ride_id);
  IF v_target IS NULL OR btrim(v_target) = '' THEN
    RETURN NULL;
  END IF;

  SELECT NULLIF(btrim(rr.rider_token), '') INTO v_token
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_id;

  v_payload := COALESCE(p_data, '{}'::jsonb)
    || jsonb_build_object('ride_request_id', p_ride_id)
    || CASE
         WHEN v_token IS NOT NULL THEN jsonb_build_object('rider_token', v_token)
         ELSE '{}'::jsonb
       END;

  RETURN public.fn_ride_event_notify(
    'rider',
    v_target,
    p_category,
    p_title,
    p_body,
    v_payload,
    COALESCE(p_priority, 'high')
  );
END;
$$;

-- Notify rider once when driver is ~1 km from pickup.
CREATE OR REPLACE FUNCTION public.fn_maybe_notify_near_pickup_for_driver(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_dist_m numeric;
  v_radius_m numeric := 1000;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.status IN ('accepted', 'assigned', 'driver_found', 'driver_en_route')
    AND rr.near_pickup_notified_at IS NULL
    AND rr.pickup_coords IS NOT NULL
  ORDER BY rr.updated_at DESC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT ST_Distance(
           ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
           v_ride.pickup_coords
         )
  INTO v_dist_m
  FROM public.driver_locations dl
  WHERE dl.driver_id = p_driver_id
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND dl.updated_at > timezone('utc', now()) - interval '5 minutes'
  LIMIT 1;

  IF v_dist_m IS NULL OR v_dist_m > v_radius_m THEN
    RETURN;
  END IF;

  UPDATE public.ride_requests
  SET near_pickup_notified_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE id = v_ride.id
    AND near_pickup_notified_at IS NULL;

  PERFORM public.fn_ride_notify_rider(
    v_ride.id,
    'driver_near_pickup',
    'Driver is nearby',
    'Your driver is about 1 km away. Come downstairs to avoid waiting fees.',
    jsonb_build_object(
      'type', 'driver_near_pickup',
      'distance_m', round(v_dist_m)
    ),
    'high'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_driver_location_near_pickup_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.fn_maybe_notify_near_pickup_for_driver(NEW.driver_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_location_near_pickup_notify ON public.driver_locations;
CREATE TRIGGER trg_driver_location_near_pickup_notify
  AFTER INSERT OR UPDATE OF latitude, longitude, updated_at
  ON public.driver_locations
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_driver_location_near_pickup_notify();

CREATE OR REPLACE FUNCTION public.trg_ride_requests_backfill_rider_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.rider_identity_id IS NULL AND NEW.rider_token IS NOT NULL THEN
    PERFORM public.fn_ensure_ride_rider_identity_for_notify(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ride_requests_backfill_rider_identity ON public.ride_requests;
CREATE TRIGGER trg_ride_requests_backfill_rider_identity
  AFTER INSERT ON public.ride_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_ride_requests_backfill_rider_identity();

-- Restore arrived notify (regression in 20260709101500).
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
    AND rr.status IN ('accepted', 'driver_en_route')
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
    AND rr.status IN ('accepted', 'driver_en_route');

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

  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'ride_arrived',
    'Your driver is outside',
    'Free pickup time: ' || (v_grace_seconds / 60)::text || ' min.',
    jsonb_build_object(
      'type', 'ride_arrived',
      'waiting_grace_seconds', v_grace_seconds,
      'waiting_rate_per_minute', COALESCE(v_waiting_rate, 0)
    ),
    'critical'
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

-- En route: use centralized rider notify helper.
CREATE OR REPLACE FUNCTION public.fn_driver_ride_en_route(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_status text;
  v_ride public.ride_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT rr.* INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  v_status := v_ride.status;

  IF v_status = 'driver_en_route' THEN
    RETURN json_build_object(
      'ok', true,
      'status', 'driver_en_route',
      'ride_id', p_ride_request_id,
      'already_en_route', true
    );
  END IF;

  IF v_status NOT IN ('accepted', 'assigned', 'driver_found') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'driver_en_route',
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status IN ('accepted', 'assigned', 'driver_found');

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.en_route',
    v_driver_id,
    jsonb_build_object('status', 'driver_en_route')
  );

  SELECT d.* INTO v_driver FROM public.drivers d WHERE d.id = v_driver_id;
  PERFORM public.fn_ride_notify_rider(
    p_ride_request_id,
    'driver_en_route',
    'Driver on the way',
    COALESCE(v_driver.full_name, 'Your driver') || ' is heading to your pickup',
    jsonb_build_object(
      'type', 'driver_en_route',
      'driver_name', v_driver.full_name
    ),
    'critical'
  );

  RETURN json_build_object(
    'ok', true,
    'status', 'driver_en_route',
    'ride_id', p_ride_request_id
  );
END;
$$;

-- Payment confirm: rider claim timestamp + notifications.
CREATE OR REPLACE FUNCTION public.fn_confirm_ride_payment(
  p_ride_id uuid,
  p_tip_eur numeric DEFAULT 0,
  p_rider_token text DEFAULT NULL,
  p_payment_method text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_driver_id uuid;
  v_is_driver boolean := false;
  v_is_rider boolean := false;
  v_base numeric;
  v_waiting numeric;
  v_tip numeric := GREATEST(COALESCE(p_tip_eur, 0), 0);
  v_method text := NULLIF(lower(btrim(COALESCE(p_payment_method, ''))), '');
  v_status text;
  v_was_driver_confirmed boolean;
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status <> 'completed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  v_was_driver_confirmed := v_ride.driver_payment_confirmed_at IS NOT NULL;

  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NOT NULL AND v_ride.driver_id = v_driver_id THEN
    v_is_driver := true;
  END IF;

  IF NOT v_is_driver THEN
    IF v_ride.rider_identity_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1 FROM public.rider_identities ri
        WHERE ri.id = v_ride.rider_identity_id AND ri.user_id = auth.uid()
      ) INTO v_is_rider;
    END IF;
    IF NOT v_is_rider
       AND p_rider_token IS NOT NULL
       AND btrim(p_rider_token) <> ''
       AND v_ride.rider_token = btrim(p_rider_token) THEN
      v_is_rider := true;
    END IF;
    IF NOT v_is_rider
       AND auth.uid() IS NOT NULL
       AND v_ride.rider_token IS NOT NULL
       AND EXISTS (
         SELECT 1 FROM public.rider_sessions rs
         WHERE rs.user_id = auth.uid()
           AND rs.session_token = v_ride.rider_token
       ) THEN
      v_is_rider := true;
    END IF;
  END IF;

  IF NOT v_is_driver AND NOT v_is_rider THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  v_base := COALESCE(
    v_ride.final_fare,
    v_ride.marketplace_offered_fare,
    v_ride.offered_fare,
    v_ride.quoted_fare,
    v_ride.estimated_fare,
    0
  );
  v_waiting := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)::numeric / 100
  END;

  IF v_method IS NULL THEN
    v_method := NULLIF(lower(btrim(COALESCE(v_ride.payment_method_settled, ''))), '');
  END IF;
  IF v_method IS NULL AND v_ride.payment_methods IS NOT NULL
     AND array_length(v_ride.payment_methods, 1) > 0 THEN
    v_method := lower(v_ride.payment_methods[1]::text);
  END IF;
  IF v_method = 'card' THEN
    v_method := 'pin';
  END IF;

  UPDATE public.ride_requests rr
  SET
    tip_amount_eur = CASE WHEN v_is_rider THEN v_tip ELSE rr.tip_amount_eur END,
    total_amount_eur = v_base + v_waiting +
      CASE WHEN v_is_rider THEN v_tip ELSE COALESCE(rr.tip_amount_eur, 0) END,
    payment_method_settled = COALESCE(v_method, rr.payment_method_settled),
    rider_payment_confirmed_at = CASE
      WHEN v_is_rider THEN timezone('utc', now())
      ELSE rr.rider_payment_confirmed_at
    END,
    driver_payment_confirmed_at = CASE
      WHEN v_is_driver THEN timezone('utc', now())
      ELSE rr.driver_payment_confirmed_at
    END,
    payment_claimed_by_rider_at = CASE
      WHEN v_is_rider AND rr.driver_payment_confirmed_at IS NULL
      THEN timezone('utc', now())
      ELSE rr.payment_claimed_by_rider_at
    END,
    payment_status = CASE
      WHEN v_is_driver THEN 'confirmed'
      WHEN v_is_rider AND rr.driver_payment_confirmed_at IS NOT NULL THEN 'confirmed'
      WHEN v_is_rider THEN 'rider_ack'
      ELSE rr.payment_status
    END,
    payment_confirmed_at = CASE
      WHEN v_is_driver THEN timezone('utc', now())
      WHEN v_is_rider AND rr.driver_payment_confirmed_at IS NOT NULL THEN timezone('utc', now())
      ELSE rr.payment_confirmed_at
    END,
    updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_id
  RETURNING payment_status INTO v_status;

  PERFORM public.fn_ride_audit_append(
    p_ride_id,
    'payment.confirmed',
    CASE WHEN v_is_driver THEN v_driver_id ELSE NULL END,
    jsonb_build_object(
      'actor', CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END,
      'tip_eur', v_tip,
      'payment_method', v_method,
      'payment_status', v_status
    )
  );

  IF v_is_driver AND v_ride.driver_id IS NOT NULL THEN
    PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_id, v_ride.driver_id);
    PERFORM public.fn_ride_notify_rider(
      p_ride_id,
      'payment_confirmed',
      'Payment received',
      'Thanks for paying. Rate your driver when you are ready.',
      jsonb_build_object('type', 'payment_confirmed', 'payment_status', v_status),
      'high'
    );
  ELSIF v_is_rider AND NOT v_was_driver_confirmed AND v_status = 'rider_ack' THEN
    PERFORM public.fn_ride_event_notify(
      'driver',
      v_ride.driver_id::text,
      'payment_rider_claim',
      'Rider says they paid',
      'The rider confirmed payment in the app. Please verify.',
      jsonb_build_object(
        'type', 'payment_rider_claim',
        'ride_request_id', p_ride_id,
        'payment_status', v_status
      ),
      'medium'
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'confirmed', v_status = 'confirmed',
    'payment_status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_confirm_ride_payment(uuid, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_confirm_ride_payment(uuid, numeric, text, text) TO authenticated;
