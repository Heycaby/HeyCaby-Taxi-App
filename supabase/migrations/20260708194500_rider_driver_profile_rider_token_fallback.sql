-- Active rides often have rider_token but NULL rider_identity_id (guest / token-only booking).
-- fn_rider_driver_profile_for_ride must authorize via token as well as identity+auth.

CREATE OR REPLACE FUNCTION public.fn_rider_driver_profile_for_ride(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT rr.driver_id INTO v_driver_id
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id IS NOT NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.rider_identities ri
        WHERE ri.id = rr.rider_identity_id
          AND ri.user_id = auth.uid()
      )
      OR (
        p_rider_token IS NOT NULL
        AND btrim(p_rider_token) <> ''
        AND rr.rider_token = btrim(p_rider_token)
      )
      OR (
        auth.uid() IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.rider_sessions rs
          WHERE rs.user_id = auth.uid()
            AND rs.session_token IS NOT NULL
            AND btrim(rs.session_token) <> ''
            AND rr.rider_token = btrim(rs.session_token)
        )
      )
    )
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'driver_id', d.id,
      'full_name', d.full_name,
      'avg_rating', d.avg_rating,
      'vehicle_plate', d.vehicle_plate,
      'profile_photo_url', d.profile_photo_url,
      'vehicle_category', d.vehicle_category,
      'vehicle_make', d.vehicle_make,
      'vehicle_model', d.vehicle_model,
      'vehicle_colour', d.vehicle_colour,
      'vehicle_photo_urls', d.vehicle_photo_urls
    )
    FROM public.drivers d
    WHERE d.id = v_driver_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_driver_profile_for_ride(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_driver_profile_for_ride(uuid, text) TO authenticated;

-- Drop old single-arg overload so PostgREST resolves the new signature cleanly.
DROP FUNCTION IF EXISTS public.fn_rider_driver_profile_for_ride(uuid);

CREATE OR REPLACE FUNCTION public.fn_rider_driver_location_for_ride(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_row jsonb;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT rr.driver_id INTO v_driver_id
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
    AND rr.driver_id IS NOT NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.rider_identities ri
        WHERE ri.id = rr.rider_identity_id
          AND ri.user_id = auth.uid()
      )
      OR (
        p_rider_token IS NOT NULL
        AND btrim(p_rider_token) <> ''
        AND rr.rider_token = btrim(p_rider_token)
      )
      OR (
        auth.uid() IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.rider_sessions rs
          WHERE rs.user_id = auth.uid()
            AND rs.session_token IS NOT NULL
            AND btrim(rs.session_token) <> ''
            AND rr.rider_token = btrim(rs.session_token)
        )
      )
    )
  LIMIT 1;

  IF v_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT jsonb_build_object(
    'driver_id', dl.driver_id,
    'latitude', dl.latitude,
    'longitude', dl.longitude,
    'heading', dl.heading,
    'updated_at', dl.updated_at
  )
  INTO v_row
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_driver_id
  ORDER BY dl.updated_at DESC NULLS LAST
  LIMIT 1;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_driver_location_for_ride(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_driver_location_for_ride(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.fn_rider_driver_location_for_ride(uuid);
