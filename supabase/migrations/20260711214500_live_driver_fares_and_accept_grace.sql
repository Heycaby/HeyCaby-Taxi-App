-- Keep acceptance validation consistent from RPC through the final row update.
-- The cohort stays immutable: only an already-created invite is accepted.
CREATE OR REPLACE FUNCTION public.trg_require_live_cohort_invite_on_accept()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_accept_grace integer := 30;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    IF to_regprocedure('public.fn_dispatch_config()') IS NOT NULL THEN
      v_accept_grace := COALESCE(
        (public.fn_dispatch_config()->>'min_driver_accept_window_seconds')::integer,
        30
      );
    END IF;

    IF NEW.driver_id IS NULL OR NOT EXISTS (
      SELECT 1
      FROM public.ride_request_invites i
      WHERE i.ride_request_id = NEW.id
        AND i.driver_id = NEW.driver_id
        AND i.status IN ('pending', 'wave_expired', 'expired')
        AND i.expires_at > now() - make_interval(secs => v_accept_grace)
    ) THEN
      RAISE EXCEPTION 'ride_invite_expired';
    END IF;
    IF OLD.expires_at IS NOT NULL
       AND OLD.expires_at <= now() - make_interval(secs => v_accept_grace) THEN
      RAISE EXCEPTION 'ride_request_expired';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_require_live_cohort_invite_on_accept()
  FROM PUBLIC, anon, authenticated;

-- Rider estimates come from drivers who are online in backend truth, using
-- their active tariffs. Distance/time are route-engine metrics supplied by the
-- app; coordinate distance remains a safe fallback for older clients.
DROP FUNCTION IF EXISTS public.fn_estimate_trip_category_prices(
  double precision, double precision, double precision, double precision
);

CREATE FUNCTION public.fn_estimate_trip_category_prices(
  p_pickup_lng double precision,
  p_pickup_lat double precision,
  p_dest_lng double precision,
  p_dest_lat double precision,
  p_distance_km double precision DEFAULT NULL,
  p_duration_min double precision DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH trip AS (
    SELECT
      GREATEST(
        COALESCE(
          NULLIF(p_distance_km, 0),
          ST_Distance(
            ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(p_dest_lng, p_dest_lat), 4326)::geography
          ) / 1000.0
        ),
        0
      )::numeric AS km,
      GREATEST(COALESCE(p_duration_min, 0), 0)::numeric AS minutes
  ), online_tariffs AS (
    SELECT DISTINCT ON (d.id)
      lower(COALESCE(NULLIF(btrim(d.vehicle_category::text), ''), 'standard')) AS category_key,
      rp.base_fare,
      rp.per_km_rate,
      rp.per_min_rate,
      rp.minimum_fare
    FROM public.drivers d
    JOIN public.driver_rate_profiles rp
      ON rp.driver_id = d.id
     AND rp.is_active = true
    WHERE d.status = 'available'
    ORDER BY d.id, rp.sort_order, rp.updated_at DESC
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'category', ot.category_key,
        'label', COALESCE(vr.display_label, initcap(ot.category_key)),
        'price', round(GREATEST(
          COALESCE(ot.minimum_fare, 0),
          COALESCE(ot.base_fare, 0)
            + COALESCE(ot.per_km_rate, 0) * t.km
            + COALESCE(ot.per_min_rate, 0) * t.minutes
        ), 2)
      )
      ORDER BY COALESCE(vr.sort_order, 999), ot.category_key
    ),
    '[]'::jsonb
  )
  FROM online_tariffs ot
  CROSS JOIN trip t
  LEFT JOIN public.vehicle_category_base_rates vr
    ON vr.category_key = ot.category_key;
$$;

REVOKE ALL ON FUNCTION public.fn_estimate_trip_category_prices(
  double precision, double precision, double precision, double precision,
  double precision, double precision
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_estimate_trip_category_prices(
  double precision, double precision, double precision, double precision,
  double precision, double precision
) TO anon, authenticated;

