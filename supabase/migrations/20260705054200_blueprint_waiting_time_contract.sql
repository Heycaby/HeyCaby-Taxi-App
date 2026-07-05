-- Backend Flow Blueprint: Waiting Time, Widget, And Waiver Contract
-- Source: docs/HEYCABY_BACKEND_FLOW_BLUEPRINT.md
-- Adds shared waiting state to ride_requests, hardens lifecycle RPCs
-- (arrival snapshot, start freeze, complete transparency), and adds
-- fn_driver_waive_waiting_fee. All guarded against duplicates.

-- 1) Waiting-time columns on ride_requests (driver_arrived_at already exists)
ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS waiting_grace_seconds integer,
  ADD COLUMN IF NOT EXISTS waiting_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS waiting_rate_per_minute numeric(10, 4),
  ADD COLUMN IF NOT EXISTS chargeable_wait_seconds integer,
  ADD COLUMN IF NOT EXISTS waiting_fee_cents integer,
  ADD COLUMN IF NOT EXISTS waiting_fee_waived boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS waiting_fee_waived_at timestamptz,
  ADD COLUMN IF NOT EXISTS waiting_fee_waived_by uuid,
  ADD COLUMN IF NOT EXISTS waiting_fee_waive_reason text;

-- 2) Shared lifecycle notification helper (new, verified absent)
CREATE OR REPLACE FUNCTION public.fn_ride_event_notify(
  p_user_type text,
  p_user_id text,
  p_category text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_priority text DEFAULT 'high'
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_user_id IS NULL OR length(trim(p_user_id)) = 0 THEN
    RETURN NULL;
  END IF;
  INSERT INTO public.notifications (
    user_type, user_id, agent, category, title, body, data, priority, channel
  ) VALUES (
    p_user_type,
    p_user_id,
    'ride_lifecycle',
    p_category,
    p_title,
    p_body,
    COALESCE(p_data, '{}'::jsonb),
    COALESCE(p_priority, 'high'),
    'both'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- 3) Arrival: proximity guard + waiting snapshot + rider notification
CREATE OR REPLACE FUNCTION public.fn_driver_ride_arrived(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_grace int;
  v_rate numeric;
  v_max_m numeric;
  v_dist_m numeric;
  v_rider_target text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status <> 'accepted' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  -- Proximity guard (default 500 m). Enforced when a fresh driver
  -- location and pickup coordinates both exist; otherwise audited only.
  v_max_m := COALESCE(NULLIF(public.fn_app_config_text('arrival_max_distance_m'), '')::numeric, 500);
  SELECT ST_Distance(
           ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
           v_ride.pickup_coords
         )
  INTO v_dist_m
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
    AND dl.updated_at > now() - interval '3 minutes'
    AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
    AND v_ride.pickup_coords IS NOT NULL
  LIMIT 1;

  IF v_dist_m IS NOT NULL AND v_dist_m > v_max_m THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'trip.arrived_blocked_distance', v_driver_id,
      jsonb_build_object('distance_m', round(v_dist_m), 'max_m', v_max_m),
      'driver', 'rpc', p_ride_request_id
    );
    RETURN json_build_object(
      'ok', false, 'error', 'too_far_from_pickup',
      'distance_m', round(v_dist_m), 'max_m', v_max_m
    );
  END IF;

  -- Waiting snapshot: grace + per-minute rate from the active tariff.
  v_grace := COALESCE(NULLIF(public.fn_app_config_text('waiting_grace_seconds'), '')::int, 120);
  SELECT rp.waiting_rate INTO v_rate
  FROM public.driver_rate_profiles rp
  WHERE rp.driver_id = v_driver_id AND rp.is_active = true
  ORDER BY rp.sort_order NULLS LAST, rp.created_at
  LIMIT 1;

  UPDATE public.ride_requests rr
  SET status = 'driver_arrived',
      driver_arrived_at = timezone('utc', now()),
      waiting_started_at = timezone('utc', now()),
      waiting_grace_seconds = v_grace,
      waiting_rate_per_minute = COALESCE(v_rate, 0),
      chargeable_wait_seconds = 0,
      waiting_fee_cents = 0,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.arrived', v_driver_id,
    jsonb_build_object(
      'status', 'driver_arrived',
      'waiting_grace_seconds', v_grace,
      'waiting_rate_per_minute', COALESCE(v_rate, 0),
      'distance_m', CASE WHEN v_dist_m IS NULL THEN NULL ELSE round(v_dist_m) END,
      'proximity_verified', v_dist_m IS NOT NULL
    )
  );

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'ride_arrived',
    'Your driver has arrived',
    'Free pickup time: ' || (v_grace / 60)::text
      || ' min. Waiting may be added after that.',
    jsonb_build_object(
      'type', 'ride_arrived',
      'ride_request_id', p_ride_request_id,
      'waiting_grace_seconds', v_grace,
      'waiting_rate_per_minute', COALESCE(v_rate, 0)
    ),
    'critical'
  );

  RETURN json_build_object(
    'ok', true, 'status', 'driver_arrived', 'ride_id', p_ride_request_id,
    'waiting_grace_seconds', v_grace,
    'waiting_rate_per_minute', COALESCE(v_rate, 0)
  );
END;
$$;

-- 4) Start ride: proximity guard + freeze waiting values + rider notification
CREATE OR REPLACE FUNCTION public.fn_driver_ride_start(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_max_m numeric;
  v_dist_m numeric;
  v_wait_secs int;
  v_fee_cents int;
  v_rider_target text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status <> 'driver_arrived' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  -- Proximity guard (default 200 m), enforced when verifiable.
  v_max_m := COALESCE(NULLIF(public.fn_app_config_text('start_max_distance_m'), '')::numeric, 200);
  SELECT ST_Distance(
           ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
           v_ride.pickup_coords
         )
  INTO v_dist_m
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
    AND dl.updated_at > now() - interval '3 minutes'
    AND dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
    AND v_ride.pickup_coords IS NOT NULL
  LIMIT 1;

  IF v_dist_m IS NOT NULL AND v_dist_m > v_max_m THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_request_id, 'trip.start_blocked_distance', v_driver_id,
      jsonb_build_object('distance_m', round(v_dist_m), 'max_m', v_max_m),
      'driver', 'rpc', p_ride_request_id
    );
    RETURN json_build_object(
      'ok', false, 'error', 'too_far_from_pickup',
      'distance_m', round(v_dist_m), 'max_m', v_max_m
    );
  END IF;

  -- Freeze waiting values at boarding.
  v_wait_secs := GREATEST(
    0,
    COALESCE(
      EXTRACT(EPOCH FROM (timezone('utc', now()) - v_ride.driver_arrived_at))::int, 0
    ) - COALESCE(v_ride.waiting_grace_seconds, 120)
  );
  IF COALESCE(v_ride.waiting_fee_waived, false) THEN
    v_fee_cents := 0;
  ELSE
    v_fee_cents := round(
      (v_wait_secs / 60.0) * COALESCE(v_ride.waiting_rate_per_minute, 0) * 100
    )::int;
  END IF;

  UPDATE public.ride_requests rr
  SET status = 'in_progress',
      started_at = timezone('utc', now()),
      chargeable_wait_seconds = v_wait_secs,
      waiting_fee_cents = v_fee_cents,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_mark_on_ride(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.started', v_driver_id,
    jsonb_build_object(
      'status', 'in_progress',
      'chargeable_wait_seconds', v_wait_secs,
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'ride_started',
    'Your trip has started',
    'Enjoy your ride.',
    jsonb_build_object(
      'type', 'ride_started',
      'ride_request_id', p_ride_request_id
    )
  );

  RETURN json_build_object(
    'ok', true, 'status', 'in_progress', 'ride_id', p_ride_request_id,
    'chargeable_wait_seconds', v_wait_secs,
    'waiting_fee_cents', v_fee_cents
  );
END;
$$;

-- 5) Complete ride: waiting transparency in audit + rider completion notification
CREATE OR REPLACE FUNCTION public.fn_driver_ride_complete(p_ride_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_updated int;
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
  v_fee_cents int;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id
     OR v_ride.status <> 'in_progress' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  v_fee_cents := CASE
    WHEN COALESCE(v_ride.waiting_fee_waived, false) THEN 0
    ELSE COALESCE(v_ride.waiting_fee_cents, 0)
  END;

  UPDATE public.ride_requests rr
  SET status = 'completed',
      completed_at = timezone('utc', now()),
      waiting_fee_cents = v_fee_cents,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_transition');
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.completed', v_driver_id,
    jsonb_build_object(
      'status', 'completed',
      'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'ride_completed',
    'Trip completed',
    'Thanks for riding with HeyCaby. Rate your driver.',
    jsonb_build_object(
      'type', 'ride_completed',
      'ride_request_id', p_ride_request_id,
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false)
    )
  );

  RETURN json_build_object(
    'ok', true, 'status', 'completed', 'ride_id', p_ride_request_id,
    'waiting_fee_cents', v_fee_cents
  );
END;
$$;

-- 6) Waive waiting fee.
--
-- Staging previously had an earlier jsonb version of this RPC. PostgreSQL
-- cannot change a function return type with CREATE OR REPLACE, so drop the
-- same-argument function first and recreate the blueprint contract.
DROP FUNCTION IF EXISTS public.fn_driver_waive_waiting_fee(uuid, text);

CREATE OR REPLACE FUNCTION public.fn_driver_waive_waiting_fee(
  p_ride_request_id uuid,
  p_reason text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_driver_id uuid;
  v_ride public.ride_requests%ROWTYPE;
  v_rider_target text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_ride.driver_id IS DISTINCT FROM v_driver_id THEN
    RETURN json_build_object('ok', false, 'error', 'not_your_ride');
  END IF;
  IF v_ride.status NOT IN ('driver_arrived', 'in_progress') THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_status');
  END IF;
  IF COALESCE(v_ride.waiting_fee_waived, false) THEN
    RETURN json_build_object('ok', true, 'already_waived', true);
  END IF;

  UPDATE public.ride_requests rr
  SET waiting_fee_waived = true,
      waiting_fee_waived_at = timezone('utc', now()),
      waiting_fee_waived_by = v_driver_id,
      waiting_fee_waive_reason = NULLIF(btrim(COALESCE(p_reason, '')), ''),
      waiting_fee_cents = 0,
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id, 'waiting.fee_waived', v_driver_id,
    jsonb_build_object('reason', p_reason),
    'driver', 'rpc', p_ride_request_id
  );

  v_rider_target := COALESCE(v_ride.rider_identity_id::text, v_ride.rider_id::text);
  PERFORM public.fn_ride_event_notify(
    'rider', v_rider_target, 'waiting_fee_waived',
    'Waiting fee waived',
    'Your driver removed the waiting charge for this ride.',
    jsonb_build_object(
      'type', 'waiting_fee_waived',
      'ride_request_id', p_ride_request_id
    )
  );

  RETURN json_build_object('ok', true, 'waived', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_waive_waiting_fee(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_event_notify(text, text, text, text, text, jsonb, text) TO authenticated;
