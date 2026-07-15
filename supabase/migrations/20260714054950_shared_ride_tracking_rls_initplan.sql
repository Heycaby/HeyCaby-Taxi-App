-- Avoid recalculating auth.uid() for every candidate ride_shares row. The
-- scalar subquery is evaluated once per statement and preserves support for
-- Supabase anonymous-auth Rider sessions (authenticated Postgres role).
DROP POLICY IF EXISTS ride_shares_select_participant ON public.ride_shares;

CREATE POLICY ride_shares_select_participant
ON public.ride_shares
FOR SELECT
TO authenticated
USING (EXISTS (
  SELECT 1
  FROM public.ride_requests rr
  WHERE rr.id = ride_shares.ride_request_id
    AND (
      rr.driver_id IN (
        SELECT d.id
        FROM public.drivers d
        WHERE d.user_id = (SELECT auth.uid())
      )
      OR rr.rider_identity_id IN (
        SELECT ri.id
        FROM public.rider_identities ri
        WHERE ri.user_id = (SELECT auth.uid())
      )
      OR rr.rider_token IN (
        SELECT rs.session_token
        FROM public.rider_sessions rs
        WHERE rs.user_id = (SELECT auth.uid())
      )
    )
));
