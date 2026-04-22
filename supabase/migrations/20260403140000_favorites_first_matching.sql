-- Prioritize rider_favorite_drivers in matching batches when favorites_first is true.
-- Does not restrict to favorites only: non-favorites are invited after, ordered by distance.

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS favorites_first boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.fn_seed_ride_matching_batch (
  p_ride_request_id uuid,
  p_batch_size int DEFAULT 4,
  p_window_seconds int DEFAULT 30
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride record;
  v_pickup geography;
  v_next_batch int;
  v_inserted int;
BEGIN
  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending'
    AND i.expires_at <= now();

  SELECT r INTO v_ride FROM public.ride_requests r WHERE r.id = p_ride_request_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_pending');
  END IF;

  v_pickup := v_ride.pickup_coords;
  IF v_pickup IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'no_pickup');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_request_invites i
    WHERE i.ride_request_id = p_ride_request_id
      AND i.status = 'pending'
      AND i.expires_at > now()
  ) THEN
    RETURN json_build_object('ok', true, 'skipped', true, 'reason', 'active_invites');
  END IF;

  SELECT COALESCE(MAX(i.batch_no), 0) + 1 INTO v_next_batch
  FROM public.ride_request_invites i
  WHERE i.ride_request_id = p_ride_request_id;

  IF v_next_batch > 20 THEN
    RETURN json_build_object('ok', false, 'error', 'max_batches');
  END IF;

  INSERT INTO public.ride_request_invites (
    ride_request_id, driver_id, batch_no, expires_at, status
  )
  SELECT
    p_ride_request_id,
    dl.driver_id,
    v_next_batch,
    now() + make_interval(secs => p_window_seconds),
    'pending'
  FROM public.driver_locations dl
  INNER JOIN public.drivers d ON d.id = dl.driver_id
  LEFT JOIN public.rider_favorite_drivers rfd
    ON rfd.driver_id = d.id
    AND rfd.rider_identity_id = v_ride.rider_identity_id
  WHERE d.status = 'available'
    AND dl.updated_at > now() - interval '3 minutes'
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND (
      (
        (
          v_ride.vehicle_categories IS NULL
          OR cardinality(v_ride.vehicle_categories) IS NULL
          OR cardinality(v_ride.vehicle_categories) = 0
        )
        AND (
          v_ride.vehicle_category IS NULL
          OR trim(both from v_ride.vehicle_category::text) = ''
          OR lower(trim(both from d.vehicle_category::text)) = lower(trim(both from v_ride.vehicle_category::text))
        )
      )
      OR (
        v_ride.vehicle_categories IS NOT NULL
        AND cardinality(v_ride.vehicle_categories) > 0
        AND lower(trim(both from d.vehicle_category::text)) = ANY (
          SELECT lower(trim(both from c))
          FROM unnest(v_ride.vehicle_categories) AS c
        )
      )
    )
    AND (
      NOT COALESCE(v_ride.pet_friendly, false)
      OR COALESCE(d.accepts_pets, false)
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites x
      WHERE x.ride_request_id = p_ride_request_id
        AND x.driver_id = dl.driver_id
    )
  ORDER BY
    CASE
      WHEN COALESCE(v_ride.favorites_first, false) THEN
        CASE WHEN rfd.driver_id IS NOT NULL THEN 0 ELSE 1 END
      ELSE 0
    END ASC,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(dl.longitude, dl.latitude), 4326)::geography,
      v_pickup
    ) ASC NULLS LAST
  LIMIT p_batch_size;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN json_build_object(
    'ok', true,
    'batch', v_next_batch,
    'invited', v_inserted
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch (uuid, int, int) TO authenticated;
