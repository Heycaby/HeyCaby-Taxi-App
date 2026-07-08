-- ============================================================
-- fn_rider_add_favorite_driver
-- Validates: completed ride, same rider, same driver, rating >= 5,
--            limit < 10, not duplicate
-- Returns: jsonb { success, favorite_id? , reason? }
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_rider_add_favorite_driver(
  p_ride_request_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ride            public.ride_requests%ROWTYPE;
  v_rider_identity_id uuid;
  v_rating_id       uuid;
  v_rating_value    smallint;
  v_active_count    integer;
  v_existing        uuid;
  v_new_id          uuid;
  v_auth_ok         boolean;
BEGIN
  -- 1. Ride exists
  SELECT * INTO v_ride
  FROM public.ride_requests
  WHERE id = p_ride_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;

  v_rider_identity_id := v_ride.rider_identity_id;

  IF v_rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rider_identity');
  END IF;

  -- 2. Auth check: if auth.uid() is available, verify ownership
  IF auth.uid() IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.rider_identities ri
      WHERE ri.id = v_rider_identity_id AND ri.user_id = auth.uid()
    ) INTO v_auth_ok;
    IF NOT v_auth_ok THEN
      RETURN jsonb_build_object('success', false, 'reason', 'not_authorized');
    END IF;
  END IF;

  -- 3. Ride is completed
  IF v_ride.status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_completed');
  END IF;

  -- 4. Driver was assigned to that ride
  IF v_ride.driver_id IS NULL OR v_ride.driver_id <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_mismatch');
  END IF;

  -- 5. Rating exists and meets threshold (>= 5)
  SELECT id, rider_rating_of_driver
  INTO v_rating_id, v_rating_value
  FROM public.ride_ratings
  WHERE ride_request_id = p_ride_request_id
    AND rider_rating_of_driver IS NOT NULL
  LIMIT 1;

  IF v_rating_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rating');
  END IF;

  IF v_rating_value < 5 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'rating_below_threshold');
  END IF;

  -- 6. Rider has fewer than 10 active favorites
  SELECT COUNT(*) INTO v_active_count
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = v_rider_identity_id
    AND is_active = true;

  IF v_active_count >= 10 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'favorite_limit_reached');
  END IF;

  -- 7. Driver is not already an active favorite
  SELECT id INTO v_existing
  FROM public.rider_favorite_drivers
  WHERE rider_identity_id = v_rider_identity_id
    AND driver_id = p_driver_id
    AND is_active = true;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_favorited', 'favorite_id', v_existing);
  END IF;

  -- 8. Insert
  INSERT INTO public.rider_favorite_drivers (
    rider_identity_id,
    driver_id,
    source_ride_request_id,
    rating_id,
    is_active
  ) VALUES (
    v_rider_identity_id,
    p_driver_id,
    p_ride_request_id,
    v_rating_id,
    true
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('success', true, 'favorite_id', v_new_id);
END;
$function$;

-- ============================================================
-- fn_rider_remove_favorite_driver
-- Soft delete: is_active = false, removed_at = now()
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_rider_remove_favorite_driver(
  p_rider_identity_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_rows integer;
BEGIN
  IF p_rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rider_identity');
  END IF;

  UPDATE public.rider_favorite_drivers
  SET is_active = false,
      removed_at = now()
  WHERE rider_identity_id = p_rider_identity_id
    AND driver_id = p_driver_id
    AND is_active = true;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_favorited');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$function$;

-- ============================================================
-- fn_rider_favorite_drivers
-- Returns: driver name, photo, rating, vehicle info, availability,
--          last ride date, favorite metadata
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_rider_favorite_drivers(
  p_rider_identity_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  IF p_rider_identity_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_rider_identity', 'drivers', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', rfd.id,
    'driver_id', rfd.driver_id,
    'driver_name', d.full_name,
    'driver_photo', d.profile_photo_url,
    'rating', COALESCE(d.rating, 5.0),
    'total_rides', COALESCE(d.trip_count, 0),
    'vehicle_make', d.vehicle_make,
    'vehicle_model', d.vehicle_model,
    'vehicle_colour', d.vehicle_colour,
    'vehicle_plate', d.vehicle_plate,
    'driver_status', d.status::text,
    'is_available', d.status = 'available',
    'created_at', rfd.created_at,
    'last_ride_completed_at', rr.completed_at
  ) ORDER BY rfd.created_at DESC), '[]'::jsonb) INTO v_result
  FROM public.rider_favorite_drivers rfd
  JOIN public.drivers d ON d.id = rfd.driver_id
  LEFT JOIN public.ride_requests rr ON rr.id = rfd.source_ride_request_id
  WHERE rfd.rider_identity_id = p_rider_identity_id
    AND rfd.is_active = true;

  RETURN jsonb_build_object('success', true, 'drivers', v_result);
END;
$function$;

-- Drop old overloads that don't take p_rider_identity_id
DROP FUNCTION IF EXISTS public.fn_rider_favorite_drivers();
DROP FUNCTION IF EXISTS public.fn_rider_remove_favorite_driver(p_driver_id uuid);
