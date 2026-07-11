-- Fix 1: Recreate driver_my_rating view with ALL columns the driver app expects.
-- The old view was missing trust_score, weighted_avg, flag_review_needed, flag_review_reason.
-- These columns exist in driver_trust_scores but were not exposed in the view.

DROP VIEW IF EXISTS public.driver_my_rating;

CREATE VIEW public.driver_my_rating AS
SELECT
  dts.driver_id,
  dts.public_stars,
  dts.trust_score,
  dts.weighted_avg,
  dts.total_valid_ratings,
  dts.avg_punctuality,
  dts.avg_cleanliness,
  dts.avg_attitude,
  dts.avg_driving_safety,
  dts.avg_communication,
  dts.flag_review_needed,
  dts.flag_review_reason,
  dts.in_protected_window,
  dts.badge_consistency,
  dts.badge_top_driver,
  dts.badge_veteran,
  dts.milestone_50_rides,
  dts.milestone_100_rides,
  dts.milestone_500_rides
FROM public.driver_trust_scores dts
WHERE dts.driver_id IN (
  SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
);

COMMENT ON VIEW public.driver_my_rating IS
  'Driver''s own trust score and rating breakdown. RLS via auth.uid() join on drivers.';

-- Fix 2: RLS on ride_ratings — rider_token is a session token string, NOT auth.uid().
-- The old policy rider_token = auth.uid()::text never matches for guest or authed riders.

DROP POLICY IF EXISTS ride_ratings_select ON public.ride_ratings;

CREATE POLICY ride_ratings_select ON public.ride_ratings
  FOR SELECT
  USING (
    driver_id IN (
      SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
    )
    OR
    ride_request_id IN (
      SELECT rr.id FROM public.ride_requests rr
      JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
      WHERE ri.user_id = auth.uid()
    )
    OR
    rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
        AND rs.session_token IS NOT NULL
        AND btrim(rs.session_token) <> ''
    )
  );

-- Fix insert policy: same rider_token mismatch
DROP POLICY IF EXISTS ride_ratings_insert ON public.ride_ratings;

CREATE POLICY ride_ratings_insert ON public.ride_ratings
  FOR INSERT
  WITH CHECK (
    driver_id IN (
      SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
    )
    OR
    rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
        AND rs.session_token IS NOT NULL
        AND btrim(rs.session_token) <> ''
    )
  );

-- Fix update policy: same rider_token = auth.uid()::text bug
DROP POLICY IF EXISTS ride_ratings_update ON public.ride_ratings;

CREATE POLICY ride_ratings_update ON public.ride_ratings
  FOR UPDATE
  USING (
    driver_id IN (
      SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
    )
    OR
    rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
        AND rs.session_token IS NOT NULL
        AND btrim(rs.session_token) <> ''
    )
  )
  WITH CHECK (
    (driver_id IN (
      SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid()
    ) AND driver_rating_of_rider >= 1 AND driver_rating_of_rider <= 5)
    OR
    (rider_token IN (
      SELECT rs.session_token FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
        AND rs.session_token IS NOT NULL
        AND btrim(rs.session_token) <> ''
    ) AND rider_rating_of_driver >= 1 AND rider_rating_of_driver <= 5)
  );

-- Fix 3: Allow anon to SELECT ride_ratings for guest rider token matching.
-- Guest riders have no auth.uid() so all existing policies block them.
-- The fn_rider_rate_driver RPC is SECURITY DEFINER (bypasses RLS for inserts),
-- but the rider app's direct SELECT on ride_ratings hits RLS.
CREATE POLICY ride_ratings_anon_select ON public.ride_ratings
  FOR SELECT
  TO anon
  USING (
    rider_token IS NOT NULL
    AND btrim(rider_token) <> ''
  );
