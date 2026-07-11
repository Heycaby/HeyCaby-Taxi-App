-- Hot NL destinations for Taxi Terug browse (driver counts per city).

CREATE OR REPLACE FUNCTION public.fn_rider_taxi_terug_hot_destinations(
  p_pickup_lat double precision DEFAULT NULL,
  p_pickup_lng double precision DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_destinations jsonb;
  v_radius_km numeric := 35;
BEGIN
  IF COALESCE((v_cfg->>'enabled')::boolean, false) IS FALSE THEN
    RETURN jsonb_build_object('enabled', false, 'destinations', '[]'::jsonb);
  END IF;

  WITH cities AS (
    SELECT *
    FROM (
      VALUES
        ('Amsterdam', 52.3676::double precision, 4.9041::double precision),
        ('Rotterdam', 51.9244::double precision, 4.4777::double precision),
        ('Utrecht', 52.0907::double precision, 5.1214::double precision),
        ('Den Haag', 52.0705::double precision, 4.3007::double precision)
    ) AS t(city, lat, lng)
  ),
  active AS (
    SELECT
      d.id,
      ST_SetSRID(
        ST_MakePoint(d.return_mode_destination_lng, d.return_mode_destination_lat),
        4326
      )::geography AS home_pos
    FROM public.drivers d
    JOIN public.driver_locations dl ON dl.driver_id = d.id
    WHERE COALESCE(d.return_mode_enabled, false) IS TRUE
      AND d.return_mode_destination_lat IS NOT NULL
      AND d.return_mode_destination_lng IS NOT NULL
      AND d.status = 'available'
      AND dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
      AND dl.updated_at > now() - make_interval(
        mins => COALESCE((v_cfg->>'gps_freshness_minutes')::int, 5)
      )
      AND COALESCE((public.fn_driver_can_accept_rides(d.id)->>'allowed')::boolean, false) IS TRUE
  ),
  counts AS (
    SELECT
      c.city,
      c.lat,
      c.lng,
      COUNT(a.id)::int AS driver_count
    FROM cities c
    LEFT JOIN active a ON
      ST_DWithin(
        a.home_pos,
        ST_SetSRID(ST_MakePoint(c.lng, c.lat), 4326)::geography,
        v_radius_km * 1000
      )
    GROUP BY c.city, c.lat, c.lng
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'city', ct.city,
        'lat', ct.lat,
        'lng', ct.lng,
        'driver_count', ct.driver_count
      )
      ORDER BY ct.driver_count DESC, ct.city ASC
    ),
    '[]'::jsonb
  )
  INTO v_destinations
  FROM counts ct;

  RETURN jsonb_build_object(
    'enabled', true,
    'destinations', v_destinations
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_taxi_terug_hot_destinations(double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_taxi_terug_hot_destinations(double precision, double precision)
  TO anon, authenticated, service_role;
