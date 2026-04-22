-- Base per-km rates for rider-facing trip estimates (editable in Supabase; no app hardcoding).
-- Multi-category matching: ride_requests.vehicle_categories drives fn_seed driver filter.

CREATE TABLE IF NOT EXISTS public.vehicle_category_base_rates (
  category_key text PRIMARY KEY,
  display_label text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  price_per_km_eur numeric(10, 2) NOT NULL CHECK (price_per_km_eur >= 0),
  active boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE public.vehicle_category_base_rates IS
  'Rider trip price estimates: category_key matches drivers.vehicle_category / rider app keys.';

INSERT INTO public.vehicle_category_base_rates (category_key, display_label, sort_order, price_per_km_eur)
VALUES
  ('standard', 'Standard', 1, 1.35),
  ('comfort', 'Comfort', 2, 1.75),
  ('taxibus', 'Taxibus', 3, 2.10),
  ('wheelchair', 'Wheelchair', 4, 1.95)
ON CONFLICT (category_key) DO NOTHING;

ALTER TABLE public.vehicle_category_base_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vehicle_category_base_rates_select_all ON public.vehicle_category_base_rates;
CREATE POLICY vehicle_category_base_rates_select_all
  ON public.vehicle_category_base_rates
  FOR SELECT
  TO anon, authenticated
  USING (active = true);

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS vehicle_categories text[];

COMMENT ON COLUMN public.ride_requests.vehicle_categories IS
  'When set, matching includes drivers in any listed category (lowercase keys).';

-- Trip estimates for the rider UI (distance * configured rate per category).
CREATE OR REPLACE FUNCTION public.fn_estimate_trip_category_prices (
  p_pickup_lng double precision,
  p_pickup_lat double precision,
  p_dest_lng double precision,
  p_dest_lat double precision
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH dist AS (
    SELECT
      ST_Distance(
        ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(p_dest_lng, p_dest_lat), 4326)::geography
      ) / 1000.0 AS km
  )
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'category', r.category_key,
        'label', r.display_label,
        'price', round((d.km * r.price_per_km_eur)::numeric, 2)
      )
      ORDER BY r.sort_order, r.category_key
    ),
    '[]'::jsonb
  )
  FROM public.vehicle_category_base_rates r
  CROSS JOIN dist d
  WHERE r.active;
$$;

GRANT EXECUTE ON FUNCTION public.fn_estimate_trip_category_prices (
  double precision, double precision, double precision, double precision
) TO anon, authenticated;

-- Match drivers when vehicle_categories is set OR fall back to single vehicle_category.
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
  ORDER BY ST_Distance(
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

