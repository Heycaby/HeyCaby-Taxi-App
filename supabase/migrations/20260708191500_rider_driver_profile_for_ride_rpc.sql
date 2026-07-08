-- Riders on an active ride must see assigned driver profile (plate, name, photo)
-- even when the driver is not marketplace-visible (verified badge + subscription).

CREATE OR REPLACE FUNCTION public.fn_rider_driver_profile_for_ride(
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

REVOKE ALL ON FUNCTION public.fn_rider_driver_profile_for_ride(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_driver_profile_for_ride(uuid) TO authenticated;
