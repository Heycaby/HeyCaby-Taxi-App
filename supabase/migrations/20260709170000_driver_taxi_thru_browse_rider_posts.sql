-- Driver Taxi Thru: browse rider posts (booking_mode = 'terug', status = 'pending')
-- Drivers see riders looking for a taxi heading their way and can accept them.

CREATE OR REPLACE FUNCTION public.fn_driver_taxi_thru_rider_posts(
  p_driver_lat double precision DEFAULT NULL,
  p_driver_lng double precision DEFAULT NULL,
  p_limit int DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cfg jsonb := public.fn_taxi_terug_config();
  v_posts jsonb;
BEGIN
  IF COALESCE((v_cfg->>'enabled')::boolean, false) IS FALSE THEN
    RETURN jsonb_build_object('enabled', false, 'posts', '[]'::jsonb);
  END IF;

  WITH base AS (
    SELECT
      rr.id,
      rr.pickup_address,
      rr.destination_address,
      rr.marketplace_offered_fare,
      rr.estimated_distance_km,
      rr.estimated_duration_min,
      rr.pickup_contact_name,
      rr.payment_methods,
      rr.created_at,
      rr.scheduled_pickup_at,
      rr.pickup_lat,
      rr.pickup_lng,
      rr.destination_lat,
      rr.destination_lng,
      rr.zone_id,
      rr.destination_zone_id,
      bz_pickup.name_display AS pickup_zone_name,
      bz_dest.name_display AS destination_zone_name,
      bz_dest.city AS destination_city,
      CASE
        WHEN p_driver_lat IS NOT NULL AND p_driver_lng IS NOT NULL
          AND rr.pickup_lat IS NOT NULL AND rr.pickup_lng IS NOT NULL
        THEN ST_Distance(
          ST_SetSRID(ST_MakePoint(p_driver_lng, p_driver_lat), 4326)::geography,
          ST_SetSRID(ST_MakePoint(rr.pickup_lng, rr.pickup_lat), 4326)::geography
        ) / 1000.0
        ELSE NULL
      END AS driver_to_pickup_km
    FROM public.ride_requests rr
    LEFT JOIN public.bubble_zones bz_pickup ON bz_pickup.id = rr.zone_id
    LEFT JOIN public.bubble_zones bz_dest ON bz_dest.id = rr.destination_zone_id
    WHERE rr.booking_mode::text = 'terug'
      AND rr.status = 'pending'
      AND rr.driver_id IS NULL
      AND (rr.expires_at IS NULL OR rr.expires_at > now())
    ORDER BY
      CASE WHEN p_driver_lat IS NOT NULL AND p_driver_lng IS NOT NULL THEN 0 ELSE 1 END,
      driver_to_pickup_km ASC NULLS LAST,
      rr.marketplace_offered_fare DESC NULLS LAST,
      rr.created_at DESC
    LIMIT GREATEST(LEAST(COALESCE(p_limit, 20), 50), 1)
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'pickup_address', b.pickup_address,
      'destination_address', b.destination_address,
      'offered_fare', b.marketplace_offered_fare,
      'estimated_distance_km', b.estimated_distance_km,
      'estimated_duration_min', b.estimated_duration_min,
      'pickup_contact_name', b.pickup_contact_name,
      'payment_methods', b.payment_methods,
      'created_at', b.created_at,
      'scheduled_pickup_at', b.scheduled_pickup_at,
      'pickup_lat', b.pickup_lat,
      'pickup_lng', b.pickup_lng,
      'destination_lat', b.destination_lat,
      'destination_lng', b.destination_lng,
      'pickup_zone_name', b.pickup_zone_name,
      'destination_zone_name', b.destination_zone_name,
      'destination_city', b.destination_city,
      'driver_to_pickup_km', b.driver_to_pickup_km
    )
  ), '[]'::jsonb)
  INTO v_posts
  FROM base b;

  RETURN jsonb_build_object(
    'enabled', true,
    'post_count', COALESCE(jsonb_array_length(v_posts), 0),
    'posts', v_posts
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_driver_taxi_thru_rider_posts(double precision, double precision, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_driver_taxi_thru_rider_posts(double precision, double precision, int) TO authenticated, service_role;
