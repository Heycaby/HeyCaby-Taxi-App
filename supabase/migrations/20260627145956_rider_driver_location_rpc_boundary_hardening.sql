-- Release hardening: keep Rider out of driver_locations table access.
-- Rider Flutter calls these RPCs instead of reading driver_locations directly.

CREATE OR REPLACE FUNCTION public.fn_rider_nearby_supply(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 12.0,
  p_max_age_minutes integer DEFAULT 3
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH params AS (
    SELECT
      p_lat AS lat,
      p_lng AS lng,
      GREATEST(COALESCE(p_radius_km, 12.0), 0.5) AS radius_km,
      GREATEST(COALESCE(p_max_age_minutes, 3), 1) AS max_age_minutes
  ),
  candidates AS (
    SELECT
      dl.driver_id,
      dl.latitude,
      dl.longitude,
      dl.updated_at,
      d.full_name,
      d.profile_photo_url,
      d.rating,
      d.base_fare,
      d.per_km_rate,
      d.vehicle_category,
      d.active_return_discount_pct,
      (
        6371.0 * 2.0 * asin(
          sqrt(
            power(sin(radians((dl.latitude - params.lat) / 2.0)), 2)
            + cos(radians(params.lat))
              * cos(radians(dl.latitude))
              * power(sin(radians((dl.longitude - params.lng) / 2.0)), 2)
          )
        )
      ) AS distance_km
    FROM params
    JOIN public.driver_locations dl
      ON dl.updated_at >= now() - make_interval(mins => params.max_age_minutes)
    JOIN public.drivers d
      ON d.id = dl.driver_id
    WHERE d.status IN ('available', 'on_ride')
      AND dl.latitude BETWEEN params.lat - (params.radius_km / 111.0)
        AND params.lat + (params.radius_km / 111.0)
      AND dl.longitude BETWEEN params.lng - (
        params.radius_km / (111.0 * GREATEST(0.35, cos(radians(params.lat))))
      ) AND params.lng + (
        params.radius_km / (111.0 * GREATEST(0.35, cos(radians(params.lat))))
      )
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'driver_id', driver_id,
        'full_name', full_name,
        'profile_photo_url', profile_photo_url,
        'rating', rating,
        'base_fare', base_fare,
        'per_km_rate', per_km_rate,
        'vehicle_category', vehicle_category,
        'active_return_discount_pct', active_return_discount_pct,
        'distance_km', distance_km
      )
      ORDER BY distance_km
    ) FILTER (WHERE distance_km <= (SELECT radius_km FROM params)),
    '[]'::jsonb
  )
  FROM candidates;
$$;

CREATE OR REPLACE FUNCTION public.fn_rider_driver_location_for_ride(
  p_ride_request_id uuid
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
    AND EXISTS (
      SELECT 1
      FROM public.rider_identities ri
      WHERE ri.id = rr.rider_identity_id
        AND ri.user_id = auth.uid()
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

REVOKE ALL ON FUNCTION public.fn_rider_nearby_supply(
  double precision,
  double precision,
  double precision,
  integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_nearby_supply(
  double precision,
  double precision,
  double precision,
  integer
) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.fn_rider_driver_location_for_ride(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_driver_location_for_ride(uuid) TO authenticated;
