-- Taxi Terug stats and ride history: count only completed rides with payment collected.

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
      AND (
        rr.driver_payment_confirmed_at IS NOT NULL
        OR COALESCE(rr.payment_status, '') IN ('confirmed', 'paid')
      )
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

COMMENT ON FUNCTION public.fn_driver_taxi_terug_stats(text) IS
  'Taxi Terug dashboard stats: completed terug rides with driver payment confirmed only.';
