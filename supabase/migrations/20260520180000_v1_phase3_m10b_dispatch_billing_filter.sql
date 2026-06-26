-- Phase 3 M10B — Dispatch: skip billing-locked drivers + batch skip metrics.
-- Live on HEYCABY-TAXI 2026-05-20. Requires M10A.

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
  v_metrics jsonb;
  v_t0 timestamptz;
  v_t1 timestamptz;
  v_duration_ms numeric;
BEGIN
  v_t0 := clock_timestamp();
  UPDATE public.ride_request_invites i
  SET status = 'expired'
  WHERE i.ride_request_id = p_ride_request_id
    AND i.status = 'pending'
    AND i.expires_at <= now();

  SELECT * INTO v_ride FROM public.ride_requests r WHERE r.id = p_ride_request_id;
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

  -- Skip metrics: one primary reason per driver (priority order)
  SELECT jsonb_build_object(
    'candidates_with_location', COUNT(*),
    'skipped_already_invited', COUNT(*) FILTER (WHERE skip_reason = 'already_invited'),
    'skipped_busy', COUNT(*) FILTER (WHERE skip_reason = 'busy'),
    'skipped_offline', COUNT(*) FILTER (WHERE skip_reason = 'offline'),
    'skipped_billing_locked', COUNT(*) FILTER (WHERE skip_reason = 'billing_locked'),
    'skipped_vehicle', COUNT(*) FILTER (WHERE skip_reason = 'vehicle'),
    'skipped_pet', COUNT(*) FILTER (WHERE skip_reason = 'pet'),
    'eligible', COUNT(*) FILTER (WHERE skip_reason = 'eligible'),
    'batch_size', p_batch_size
  )
  INTO v_metrics
  FROM (
    SELECT
      dl.driver_id,
      CASE
        WHEN EXISTS (
          SELECT 1 FROM public.ride_request_invites x
          WHERE x.ride_request_id = p_ride_request_id AND x.driver_id = dl.driver_id
        ) THEN 'already_invited'
        WHEN d.status IS DISTINCT FROM 'available' THEN 'busy'
        WHEN dl.updated_at <= now() - interval '3 minutes' THEN 'offline'
        WHEN COALESCE((public.fn_driver_can_accept_rides(dl.driver_id)->>'allowed')::boolean, false) = false
          THEN 'billing_locked'
        WHEN NOT (
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
        ) THEN 'vehicle'
        WHEN COALESCE(v_ride.pet_friendly, false)
          AND NOT COALESCE(d.accepts_pets, false) THEN 'pet'
        ELSE 'eligible'
      END AS skip_reason
    FROM public.driver_locations dl
    INNER JOIN public.drivers d ON d.id = dl.driver_id
    WHERE dl.latitude IS NOT NULL
      AND dl.longitude IS NOT NULL
  ) tagged;

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
    AND COALESCE((public.fn_driver_can_accept_rides(dl.driver_id)->>'allowed')::boolean, false) = true
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

  v_t1 := clock_timestamp();
  v_duration_ms := EXTRACT(MILLISECONDS FROM (v_t1 - v_t0));

  v_metrics := v_metrics || jsonb_build_object(
    'invited', v_inserted,
    'dispatch_duration_ms', round(v_duration_ms)::int,
    'dispatch_version', 1
  );

  PERFORM public.fn_ride_audit_append(
    p_ride_request_id,
    'dispatch.batch_seeded',
    NULL,
    jsonb_build_object(
      'batch_no', v_next_batch,
      'skip_metrics', v_metrics,
      'dispatch_version', 1
    ),
    'system',
    'supabase_trigger',
    p_ride_request_id
  );

  RETURN json_build_object(
    'ok', true,
    'batch', v_next_batch,
    'invited', v_inserted,
    'skip_metrics', v_metrics,
    'dispatch_version', 1,
    'dispatch_duration_ms', round(v_duration_ms)::int
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_seed_ride_matching_batch (uuid, int, int) TO authenticated;
