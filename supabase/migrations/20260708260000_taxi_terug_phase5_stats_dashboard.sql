-- Taxi Terug Phase 5: empty-km saved + earnings dashboard.

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_fare_euros(p_ride public.ride_requests)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    p_ride.final_fare::numeric,
    p_ride.quoted_fare::numeric,
    p_ride.offered_fare::numeric,
    p_ride.marketplace_offered_fare::numeric,
    p_ride.estimated_fare::numeric,
    0
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_empty_km_for_ride(p_ride public.ride_requests)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN 0::numeric
    ELSE round(COALESCE(p_ride.estimated_distance_km, 0)::numeric, 1)
  END;
$$;

CREATE OR REPLACE FUNCTION public.fn_taxi_terug_record_completion(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_empty_km numeric;
  v_earnings numeric;
BEGIN
  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = p_driver_id;

  IF NOT FOUND OR v_ride.booking_mode::text IS DISTINCT FROM 'terug' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_terug_ride');
  END IF;

  v_empty_km := public.fn_taxi_terug_empty_km_for_ride(v_ride);
  v_earnings := round(public.fn_taxi_terug_fare_euros(v_ride), 2);

  UPDATE public.ride_requests rr
  SET dispatch_state = COALESCE(rr.dispatch_state, '{}'::jsonb) || jsonb_build_object(
        'empty_km_saved', v_empty_km,
        'taxi_terug_earnings_euros', v_earnings,
        'stats_recorded_at', timezone('utc', now())
      ),
      updated_at = timezone('utc', now())
  WHERE rr.id = p_ride_request_id;

  INSERT INTO public.driver_return_mode_events (driver_id, event_type, payload)
  VALUES (
    p_driver_id,
    'taxi_terug.ride_completed',
    jsonb_build_object(
      'ride_request_id', p_ride_request_id,
      'empty_km_saved', v_empty_km,
      'earnings_euros', v_earnings
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'empty_km_saved', v_empty_km,
    'earnings_euros', v_earnings
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_driver_taxi_terug_stats(
  p_period text DEFAULT 'month'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_period text := lower(COALESCE(NULLIF(btrim(p_period), ''), 'month'));
  v_start timestamptz;
  v_month_start timestamptz;
  v_week_start timestamptz;
  v_today_start timestamptz;
  v_period_rides int;
  v_period_km numeric;
  v_period_euros numeric;
  v_month_rides int;
  v_month_km numeric;
  v_month_euros numeric;
  v_week_rides int;
  v_week_km numeric;
  v_week_euros numeric;
  v_today_rides int;
  v_today_km numeric;
  v_today_euros numeric;
  v_all_rides int;
  v_all_km numeric;
  v_all_euros numeric;
BEGIN
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = auth.uid()
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_a_driver');
  END IF;

  v_today_start := date_trunc('day', timezone('utc', now()));
  v_week_start := date_trunc('week', timezone('utc', now()));
  v_month_start := date_trunc('month', timezone('utc', now()));

  v_start := CASE v_period
    WHEN 'today' THEN v_today_start
    WHEN 'week' THEN v_week_start
    ELSE v_month_start
  END;

  WITH rides AS (
    SELECT
      rr.completed_at,
      COALESCE(
        (rr.dispatch_state->>'empty_km_saved')::numeric,
        public.fn_taxi_terug_empty_km_for_ride(rr)
      ) AS empty_km_saved,
      COALESCE(
        (rr.dispatch_state->>'taxi_terug_earnings_euros')::numeric,
        public.fn_taxi_terug_fare_euros(rr)
      ) AS earnings_euros
    FROM public.ride_requests rr
    WHERE rr.driver_id = v_driver_id
      AND rr.booking_mode::text = 'terug'
      AND rr.status = 'completed'
      AND rr.completed_at IS NOT NULL
  ),
  period_agg AS (
    SELECT
      COUNT(*)::int AS rides,
      round(COALESCE(SUM(empty_km_saved), 0), 1) AS km,
      round(COALESCE(SUM(earnings_euros), 0), 2) AS euros
    FROM rides
    WHERE completed_at >= v_start
  ),
  month_agg AS (
    SELECT
      COUNT(*)::int AS rides,
      round(COALESCE(SUM(empty_km_saved), 0), 1) AS km,
      round(COALESCE(SUM(earnings_euros), 0), 2) AS euros
    FROM rides
    WHERE completed_at >= v_month_start
  ),
  week_agg AS (
    SELECT
      COUNT(*)::int AS rides,
      round(COALESCE(SUM(empty_km_saved), 0), 1) AS km,
      round(COALESCE(SUM(earnings_euros), 0), 2) AS euros
    FROM rides
    WHERE completed_at >= v_week_start
  ),
  today_agg AS (
    SELECT
      COUNT(*)::int AS rides,
      round(COALESCE(SUM(empty_km_saved), 0), 1) AS km,
      round(COALESCE(SUM(earnings_euros), 0), 2) AS euros
    FROM rides
    WHERE completed_at >= v_today_start
  ),
  all_agg AS (
    SELECT
      COUNT(*)::int AS rides,
      round(COALESCE(SUM(empty_km_saved), 0), 1) AS km,
      round(COALESCE(SUM(earnings_euros), 0), 2) AS euros
    FROM rides
  )
  SELECT
    p.rides, p.km, p.euros,
    m.rides, m.km, m.euros,
    w.rides, w.km, w.euros,
    t.rides, t.km, t.euros,
    a.rides, a.km, a.euros
  INTO
    v_period_rides, v_period_km, v_period_euros,
    v_month_rides, v_month_km, v_month_euros,
    v_week_rides, v_week_km, v_week_euros,
    v_today_rides, v_today_km, v_today_euros,
    v_all_rides, v_all_km, v_all_euros
  FROM period_agg p, month_agg m, week_agg w, today_agg t, all_agg a;

  RETURN jsonb_build_object(
    'ok', true,
    'period', v_period,
    'rides_completed', v_period_rides,
    'empty_km_saved', v_period_km,
    'earnings_euros', v_period_euros,
    'month_rides', v_month_rides,
    'month_empty_km_saved', v_month_km,
    'month_earnings_euros', v_month_euros,
    'week_rides', v_week_rides,
    'week_empty_km_saved', v_week_km,
    'week_earnings_euros', v_week_euros,
    'today_rides', v_today_rides,
    'today_empty_km_saved', v_today_km,
    'today_earnings_euros', v_today_euros,
    'all_time_rides', v_all_rides,
    'all_time_empty_km_saved', v_all_km,
    'all_time_earnings_euros', v_all_euros
  );
END;
$$;

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
  v_queued jsonb;
  v_terug_stats jsonb;
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

  IF v_ride.booking_mode::text = 'terug' THEN
    v_terug_stats := public.fn_taxi_terug_record_completion(p_ride_request_id, v_driver_id);
  END IF;

  PERFORM public.fn_driver_ride_lifecycle_release_driver(v_driver_id);
  v_queued := public.fn_taxi_terug_activate_queued_ride(v_driver_id, p_ride_request_id);
  PERFORM public.fn_driver_ride_issue_auto_receipt(p_ride_request_id, v_driver_id);
  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id, 'trip.completed', v_driver_id,
    jsonb_build_object(
      'status', 'completed',
      'chargeable_wait_seconds', COALESCE(v_ride.chargeable_wait_seconds, 0),
      'waiting_fee_cents', v_fee_cents,
      'waiting_fee_waived', COALESCE(v_ride.waiting_fee_waived, false),
      'queued_taxi_terug_activated', COALESCE((v_queued->>'ok')::boolean, false),
      'taxi_terug_stats', v_terug_stats
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
    'waiting_fee_cents', v_fee_cents,
    'queued_taxi_terug_activated', COALESCE((v_queued->>'ok')::boolean, false),
    'taxi_terug_empty_km_saved', v_terug_stats->>'empty_km_saved',
    'taxi_terug_earnings_euros', v_terug_stats->>'earnings_euros'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_fare_euros(public.ride_requests) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_empty_km_for_ride(public.ride_requests) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_record_completion(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_driver_taxi_terug_stats(text) TO authenticated, service_role;
