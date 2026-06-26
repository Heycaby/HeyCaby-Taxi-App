-- Onboarding V2: lifetime completed ride count for progressive verification milestones.

CREATE OR REPLACE FUNCTION public.fn_driver_lifetime_completed_rides(p_driver_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::integer
  FROM public.ride_requests rr
  WHERE rr.driver_id = p_driver_id
    AND rr.status = 'completed';
$$;

REVOKE ALL ON FUNCTION public.fn_driver_lifetime_completed_rides(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_lifetime_completed_rides(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_driver_lifetime_completed_rides(uuid) TO service_role;
