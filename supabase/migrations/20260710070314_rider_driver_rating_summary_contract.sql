-- Rider + driver self-rating summaries.
-- Keeps each direction's written feedback separate and exposes only the
-- authenticated user's own aggregate through SECURITY DEFINER RPCs.

ALTER TABLE public.ride_ratings
  ADD COLUMN IF NOT EXISTS driver_comment text;

COMMENT ON COLUMN public.ride_ratings.driver_comment IS
  'Optional private feedback written by the assigned driver about the rider.';

-- Historical rows where only the driver had rated can be identified safely.
UPDATE public.ride_ratings
SET driver_comment = rider_comment,
    rider_comment = NULL
WHERE driver_comment IS NULL
  AND driver_rated_at IS NOT NULL
  AND rider_rated_at IS NULL
  AND rider_comment IS NOT NULL
  AND btrim(rider_comment) <> '';

CREATE OR REPLACE FUNCTION public.fn_reveal_mutual_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.rider_rating_of_driver IS NOT NULL
     AND NEW.driver_rating_of_rider IS NOT NULL
     AND NEW.ratings_revealed_at IS NULL THEN
    NEW.ratings_revealed_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_reveal_mutual_rating() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_reveal_mutual_rating() TO service_role;

DROP TRIGGER IF EXISTS trg_reveal_mutual_rating ON public.ride_ratings;
CREATE TRIGGER trg_reveal_mutual_rating
BEFORE INSERT OR UPDATE OF rider_rating_of_driver, driver_rating_of_rider
ON public.ride_ratings
FOR EACH ROW
EXECUTE FUNCTION public.fn_reveal_mutual_rating();

UPDATE public.ride_ratings
SET ratings_revealed_at = COALESCE(
  ratings_revealed_at,
  GREATEST(rider_rated_at, driver_rated_at, created_at)
)
WHERE rider_rating_of_driver IS NOT NULL
  AND driver_rating_of_rider IS NOT NULL
  AND ratings_revealed_at IS NULL;

CREATE OR REPLACE FUNCTION public.fn_driver_rate_rider(
  p_ride_request_id uuid,
  p_rating smallint,
  p_comment text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_ride public.ride_requests%ROWTYPE;
  v_comment text;
BEGIN
  v_driver_id := public.fn_driver_ride_lifecycle_resolve_driver();
  IF v_driver_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_rating');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id = v_driver_id
    AND rr.status = 'completed';

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_completed');
  END IF;

  IF v_ride.rider_token IS NULL OR btrim(v_ride.rider_token) = '' THEN
    RETURN json_build_object('ok', false, 'error', 'missing_rider_token');
  END IF;

  v_comment := NULLIF(btrim(COALESCE(p_comment, '')), '');
  IF v_comment IS NOT NULL AND char_length(v_comment) > 300 THEN
    v_comment := left(v_comment, 300);
  END IF;

  INSERT INTO public.ride_ratings (
    ride_request_id,
    driver_id,
    rider_token,
    driver_rating_of_rider,
    driver_rated_at,
    driver_comment
  )
  VALUES (
    p_ride_request_id,
    v_driver_id,
    v_ride.rider_token,
    p_rating,
    timezone('utc', now()),
    v_comment
  )
  ON CONFLICT (ride_request_id) DO UPDATE
  SET
    driver_rating_of_rider = EXCLUDED.driver_rating_of_rider,
    driver_rated_at = EXCLUDED.driver_rated_at,
    driver_comment = COALESCE(EXCLUDED.driver_comment, public.ride_ratings.driver_comment);

  PERFORM public.fn_driver_ride_lifecycle_audit(
    p_ride_request_id,
    'trip.rated',
    v_driver_id,
    jsonb_build_object('rating', p_rating)
  );

  RETURN json_build_object('ok', true, 'ride_id', p_ride_request_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_rate_rider(uuid, smallint, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_rate_rider(uuid, smallint, text)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_rider_my_rating_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_total integer := 0;
  v_average numeric;
  v_distribution jsonb;
  v_comments jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  WITH owned_rides AS (
    SELECT rr.id
    FROM public.ride_requests rr
    LEFT JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
    WHERE ri.user_id = v_uid
       OR rr.rider_token IN (
         SELECT rs.session_token
         FROM public.rider_sessions rs
         WHERE rs.user_id = v_uid
           AND rs.session_token IS NOT NULL
           AND btrim(rs.session_token) <> ''
       )
  ), eligible AS (
    SELECT r.*
    FROM public.ride_ratings r
    JOIN owned_rides o ON o.id = r.ride_request_id
    WHERE r.driver_rating_of_rider BETWEEN 1 AND 5
      AND COALESCE(r.admin_excluded, false) = false
  )
  SELECT
    count(*)::integer,
    round(avg(driver_rating_of_rider)::numeric, 2),
    jsonb_build_object(
      '5', count(*) FILTER (WHERE driver_rating_of_rider = 5),
      '4', count(*) FILTER (WHERE driver_rating_of_rider = 4),
      '3', count(*) FILTER (WHERE driver_rating_of_rider = 3),
      '2', count(*) FILTER (WHERE driver_rating_of_rider = 2),
      '1', count(*) FILTER (WHERE driver_rating_of_rider = 1)
    )
  INTO v_total, v_average, v_distribution
  FROM eligible;

  WITH owned_rides AS (
    SELECT rr.id
    FROM public.ride_requests rr
    LEFT JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
    WHERE ri.user_id = v_uid
       OR rr.rider_token IN (
         SELECT rs.session_token
         FROM public.rider_sessions rs
         WHERE rs.user_id = v_uid
           AND rs.session_token IS NOT NULL
           AND btrim(rs.session_token) <> ''
       )
  )
  SELECT COALESCE(jsonb_agg(item ORDER BY rated_at DESC), '[]'::jsonb)
  INTO v_comments
  FROM (
    SELECT jsonb_build_object(
      'rating', r.driver_rating_of_rider,
      'comment', r.driver_comment,
      'created_at', r.driver_rated_at
    ) AS item,
    r.driver_rated_at AS rated_at
    FROM public.ride_ratings r
    JOIN owned_rides o ON o.id = r.ride_request_id
    WHERE r.driver_comment IS NOT NULL
      AND btrim(r.driver_comment) <> ''
      AND r.ratings_revealed_at IS NOT NULL
      AND COALESCE(r.admin_excluded, false) = false
    ORDER BY r.driver_rated_at DESC NULLS LAST
    LIMIT 20
  ) recent;

  RETURN jsonb_build_object(
    'ok', true,
    'average_rating', COALESCE(v_average, 0),
    'total_ratings', v_total,
    'five_star_count', COALESCE((v_distribution ->> '5')::integer, 0),
    'distribution', COALESCE(v_distribution, '{"5":0,"4":0,"3":0,"2":0,"1":0}'::jsonb),
    'comments', COALESCE(v_comments, '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_my_rating_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_my_rating_summary()
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_driver_my_rating_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver_id uuid;
  v_total integer := 0;
  v_average numeric := 0;
  v_distribution jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_uid
  ORDER BY d.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_a_driver');
  END IF;

  SELECT
    count(*)::integer,
    round(avg(r.rider_rating_of_driver)::numeric, 2),
    jsonb_build_object(
      '5', count(*) FILTER (WHERE r.rider_rating_of_driver = 5),
      '4', count(*) FILTER (WHERE r.rider_rating_of_driver = 4),
      '3', count(*) FILTER (WHERE r.rider_rating_of_driver = 3),
      '2', count(*) FILTER (WHERE r.rider_rating_of_driver = 2),
      '1', count(*) FILTER (WHERE r.rider_rating_of_driver = 1)
    )
  INTO v_total, v_average, v_distribution
  FROM public.ride_ratings r
  WHERE r.driver_id = v_driver_id
    AND r.rider_rating_of_driver BETWEEN 1 AND 5
    AND COALESCE(r.admin_excluded, false) = false;

  RETURN jsonb_build_object(
    'ok', true,
    'average_rating', COALESCE(v_average, 0),
    'total_ratings', v_total,
    'five_star_count', COALESCE((v_distribution ->> '5')::integer, 0),
    'distribution', COALESCE(v_distribution, '{"5":0,"4":0,"3":0,"2":0,"1":0}'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_my_rating_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_driver_my_rating_summary()
  TO authenticated, service_role;

-- The profile no longer reads this table directly. Remove the former policy
-- that exposed every non-empty rider token to the anonymous API role.
DROP POLICY IF EXISTS ride_ratings_anon_select ON public.ride_ratings;
REVOKE SELECT ON TABLE public.ride_ratings FROM anon;

COMMENT ON FUNCTION public.fn_rider_my_rating_summary() IS
  'Authenticated rider self-summary: exact star counts and mutually revealed driver comments.';
COMMENT ON FUNCTION public.fn_driver_my_rating_summary() IS
  'Authenticated driver self-summary: exact star distribution for the signed-in driver.';
