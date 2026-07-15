-- Production history 20260713105019: Earnings goals include biweekly and monthly target types.

ALTER TABLE public.driver_earnings_targets
  DROP CONSTRAINT IF EXISTS driver_earnings_targets_target_type_check;

ALTER TABLE public.driver_earnings_targets
  ADD CONSTRAINT driver_earnings_targets_target_type_check
  CHECK (target_type = ANY (ARRAY[
    'daily'::text,
    'weekly'::text,
    'biweekly'::text,
    'monthly'::text
  ]));

DROP FUNCTION IF EXISTS public.get_driver_earnings_summary(uuid);

CREATE OR REPLACE FUNCTION public.get_driver_earnings_summary(p_driver_id uuid)
RETURNS TABLE(
  today_earnings numeric,
  today_rides integer,
  week_earnings numeric,
  week_rides integer,
  biweekly_earnings numeric,
  biweekly_rides integer,
  month_earnings numeric,
  month_rides integer,
  shift_online_minutes integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_shift_minutes INTEGER;
BEGIN
  SELECT COALESCE(shift_total_online_minutes, 0)
  INTO v_shift_minutes
  FROM public.drivers
  WHERE id = p_driver_id;

  RETURN QUERY
  SELECT
    COALESCE(SUM(CASE WHEN dth.completed_at >= CURRENT_DATE THEN r.final_fare ELSE 0 END), 0)::NUMERIC,
    COUNT(CASE WHEN dth.completed_at >= CURRENT_DATE THEN 1 END)::INTEGER,
    COALESCE(SUM(CASE WHEN dth.completed_at >= DATE_TRUNC('week', now()) THEN r.final_fare ELSE 0 END), 0)::NUMERIC,
    COUNT(CASE WHEN dth.completed_at >= DATE_TRUNC('week', now()) THEN 1 END)::INTEGER,
    COALESCE(SUM(CASE WHEN dth.completed_at >= (CURRENT_DATE - INTERVAL '13 days') THEN r.final_fare ELSE 0 END), 0)::NUMERIC,
    COUNT(CASE WHEN dth.completed_at >= (CURRENT_DATE - INTERVAL '13 days') THEN 1 END)::INTEGER,
    COALESCE(SUM(CASE WHEN dth.completed_at >= DATE_TRUNC('month', now()) THEN r.final_fare ELSE 0 END), 0)::NUMERIC,
    COUNT(CASE WHEN dth.completed_at >= DATE_TRUNC('month', now()) THEN 1 END)::INTEGER,
    v_shift_minutes
  FROM public.driver_trip_history dth
  LEFT JOIN public.rides r ON r.ride_request_id = dth.ride_request_id
  WHERE dth.driver_id = p_driver_id
    AND dth.completed_at >= DATE_TRUNC('month', now());
END;
$function$;
