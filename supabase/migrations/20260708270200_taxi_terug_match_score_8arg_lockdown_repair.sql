-- Repair: phase-3 added fn_taxi_terug_match_score(..., p_wait_minutes) as a separate
-- overload; the main lockdown migration only revoked the 7-arg signature.

REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(
  numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.fn_taxi_terug_match_score(
  numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric
) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.fn_taxi_terug_match_score(
  numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric
) TO service_role;
