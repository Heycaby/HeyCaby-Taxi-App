-- Lightweight RPC returning total completed rides for a rider.
-- Used by the community/gamification screen for ride-based badges.
-- No new tables — just counts from ride_requests.

CREATE OR REPLACE FUNCTION public.fn_rider_ride_milestones(
  p_rider_token text
) RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT json_build_object(
    'total_completed_rides', COUNT(*)::int
  )
  FROM ride_requests
  WHERE rider_token = p_rider_token
    AND status = 'completed';
$$;

GRANT EXECUTE ON FUNCTION public.fn_rider_ride_milestones(text) TO authenticated, anon;
