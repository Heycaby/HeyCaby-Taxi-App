-- Canonical finance metrics RPC for Driver app + client telemetry sink.

CREATE TABLE IF NOT EXISTS public.driver_client_telemetry_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  driver_id uuid NULL REFERENCES public.drivers(id) ON DELETE SET NULL,
  scope text NOT NULL,
  event text NOT NULL,
  detail text NULL,
  extra jsonb NULL
);

ALTER TABLE public.driver_client_telemetry_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_client_telemetry_insert_own ON public.driver_client_telemetry_events;
CREATE POLICY driver_client_telemetry_insert_own
  ON public.driver_client_telemetry_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
  );

DROP POLICY IF EXISTS driver_client_telemetry_select_none ON public.driver_client_telemetry_events;
CREATE POLICY driver_client_telemetry_select_none
  ON public.driver_client_telemetry_events
  FOR SELECT
  TO authenticated
  USING (false);

CREATE OR REPLACE FUNCTION public.fn_driver_log_client_telemetry(
  p_scope text,
  p_event text,
  p_detail text DEFAULT NULL,
  p_extra jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_driver_id uuid;
BEGIN
  SELECT d.id
  INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_user_id
  LIMIT 1;

  INSERT INTO public.driver_client_telemetry_events(
    user_id,
    driver_id,
    scope,
    event,
    detail,
    extra
  )
  VALUES (
    v_user_id,
    v_driver_id,
    COALESCE(NULLIF(trim(p_scope), ''), 'unknown'),
    COALESCE(NULLIF(trim(p_event), ''), 'unknown'),
    p_detail,
    p_extra
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

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
      COALESCE(rr.estimated_distance_km::numeric, 0) AS distance_km,
      rr.completed_at
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
      COUNT(*)::int AS total_rides,
      COALESCE(SUM(distance_km), 0) AS total_kilometers
    FROM completed
  ),
  agg_cancelled AS (
    SELECT
      COUNT(*)::int AS cancelled_rides,
      COALESCE(SUM(cancellation_fee), 0) AS cancellation_fees
    FROM cancelled
  )
  SELECT jsonb_build_object(
    'gross_earnings', ac.gross_earnings::float8,
    'net_earnings', ac.gross_earnings::float8,
    'total_rides', ac.total_rides,
    'total_kilometers', ac.total_kilometers::float8,
    'platform_fees', NULL,
    'tips', NULL,
    'completed_rides', ac.total_rides,
    'cancelled_rides', ax.cancelled_rides,
    'cancellation_fees', ax.cancellation_fees::float8
  )
  FROM agg_completed ac, agg_cancelled ax;
$$;
