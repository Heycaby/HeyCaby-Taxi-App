-- Enhanced fn_driver_finance_metrics: add tips, hours online, average fare,
-- total shifts, and per-ride breakdown rows for the financial reporting screen.
-- Additive: replaces the existing function with an enriched version.

CREATE OR REPLACE FUNCTION public.fn_driver_finance_metrics(
  p_driver_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH bounds AS (
    SELECT
      LEAST(p_start, p_end) AS s,
      GREATEST(p_start, p_end) AS e
  ),
  completed AS (
    SELECT
      rr.id,
      COALESCE(
        rr.marketplace_offered_fare::numeric,
        rr.offered_fare::numeric,
        rr.estimated_price::numeric,
        0
      ) AS fare,
      COALESCE(rr.tip_amount_eur::numeric, 0) AS tip,
      COALESCE(rr.estimated_distance_km::numeric, 0) AS distance_km,
      rr.completed_at,
      rr.started_at,
      rr.payment_method_settled
    FROM public.ride_requests rr
    CROSS JOIN bounds b
    WHERE rr.driver_id = p_driver_id
      AND rr.status = 'completed'
      AND rr.completed_at >= b.s
      AND rr.completed_at <= b.e
  ),
  cancelled AS (
    SELECT
      rr.id,
      COALESCE(
        rr.preride_commitment_fee_euros::numeric,
        rr.commitment_fee_amount::numeric,
        0
      ) AS cancellation_fee
    FROM public.ride_requests rr
    CROSS JOIN bounds b
    WHERE rr.driver_id = p_driver_id
      AND rr.status = 'cancelled'
      AND COALESCE(rr.cancelled_at, rr.updated_at, rr.created_at) >= b.s
      AND COALESCE(rr.cancelled_at, rr.updated_at, rr.created_at) <= b.e
  ),
  agg_completed AS (
    SELECT
      COALESCE(SUM(fare), 0) AS gross_earnings,
      COALESCE(SUM(tip), 0) AS total_tips,
      COUNT(*)::int AS total_rides,
      COALESCE(SUM(distance_km), 0) AS total_kilometers,
      CASE WHEN COUNT(*) > 0
        THEN COALESCE(SUM(fare), 0) / COUNT(*)
        ELSE 0
      END AS average_fare
    FROM completed
  ),
  agg_cancelled AS (
    SELECT
      COUNT(*)::int AS cancelled_rides,
      COALESCE(SUM(cancellation_fee), 0) AS cancellation_fees
    FROM cancelled
  ),
  shift_hours AS (
    SELECT
      COALESCE(
        SUM(
          EXTRACT(EPOCH FROM (
            COALESCE(shift_ended_at, timezone('utc', now())) - shift_started_at
          )) / 3600
        ),
        0
      )::float8 AS hours_online,
      COUNT(*)::int AS total_shifts
    FROM public.driver_shift_sessions
    WHERE driver_id = p_driver_id
      AND shift_started_at >= (SELECT s FROM bounds)
      AND shift_started_at <= (SELECT e FROM bounds)
  ),
  ride_rows AS (
    SELECT
      c.id,
      c.fare::float8 AS fare,
      c.tip::float8 AS tip,
      c.distance_km::float8 AS distance_km,
      c.completed_at,
      c.payment_method_settled,
      c.started_at
    FROM completed c
    ORDER BY c.completed_at DESC
    LIMIT 200
  )
  SELECT jsonb_build_object(
    'gross_earnings', ac.gross_earnings::float8,
    'net_earnings', ac.gross_earnings::float8,
    'total_rides', ac.total_rides,
    'total_kilometers', ac.total_kilometers::float8,
    'platform_fees', NULL,
    'tips', ac.total_tips::float8,
    'completed_rides', ac.total_rides,
    'cancelled_rides', ax.cancelled_rides,
    'cancellation_fees', ax.cancellation_fees::float8,
    'average_fare', ac.average_fare::float8,
    'hours_online', sh.hours_online,
    'total_shifts', sh.total_shifts,
    'ride_breakdown', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'fare', r.fare,
          'tip', r.tip,
          'distance_km', r.distance_km,
          'completed_at', to_char(r.completed_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'payment_method', r.payment_method_settled
        )
      ) FROM ride_rows r),
      '[]'::jsonb
    )
  )
  FROM agg_completed ac, agg_cancelled ax, shift_hours sh;
$$;

-- Per-ride detail rows for the financial report.
CREATE OR REPLACE FUNCTION public.fn_driver_finance_rides(
  p_driver_id uuid,
  p_start timestamptz,
  p_end timestamptz,
  p_limit int DEFAULT 500
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', rr.id,
        'fare', COALESCE(
          rr.marketplace_offered_fare::numeric,
          rr.offered_fare::numeric,
          rr.estimated_price::numeric,
          0
        )::float8,
        'tip', COALESCE(rr.tip_amount_eur::numeric, 0)::float8,
        'distance_km', COALESCE(rr.estimated_distance_km::numeric, 0)::float8,
        'completed_at', to_char(rr.completed_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'pickup_address', rr.pickup_address,
        'destination_address', rr.destination_address,
        'payment_method', rr.payment_method_settled,
        'status', rr.status
      )
      ORDER BY rr.completed_at DESC
    ),
    '[]'::jsonb
  )
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.status = 'completed'
    AND rr.completed_at >= LEAST(p_start, p_end)
    AND rr.completed_at <= GREATEST(p_start, p_end)
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.fn_driver_finance_rides(uuid, timestamptz, timestamptz, int) TO authenticated;
