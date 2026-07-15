-- Keep the Driver app's post-accept tariff calculation in the same backend
-- transaction that assigns the ride. Existing Rider/marketplace quotes retain
-- priority; only rides without a positive fare snapshot use the accepting
-- Driver's active tariff. The formula intentionally matches the released app.

CREATE OR REPLACE FUNCTION private.fn_resolve_accept_fare_snapshot(
  p_driver_id uuid,
  p_existing_fare numeric,
  p_distance_km numeric,
  p_duration_min numeric
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_profile public.driver_rate_profiles%ROWTYPE;
  v_fare numeric;
BEGIN
  IF p_existing_fare > 0 THEN
    RETURN jsonb_build_object(
      'fare', round(p_existing_fare, 2),
      'source', 'existing_snapshot'
    );
  END IF;

  IF p_driver_id IS NULL OR p_distance_km IS NULL OR p_distance_km < 0 THEN
    RETURN jsonb_build_object(
      'fare', NULL,
      'source', 'missing_distance'
    );
  END IF;

  SELECT rp.*
  INTO v_profile
  FROM public.driver_rate_profiles rp
  WHERE rp.driver_id = p_driver_id
    AND rp.is_active = true
  ORDER BY rp.sort_order ASC, rp.updated_at DESC, rp.id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'fare', NULL,
      'source', 'missing_tariff'
    );
  END IF;

  v_fare := round(
    GREATEST(
      v_profile.minimum_fare,
      v_profile.base_fare
        + (v_profile.per_km_rate * p_distance_km)
        + (v_profile.per_min_rate * COALESCE(p_duration_min, 0))
    ),
    2
  );

  RETURN jsonb_build_object(
    'fare', v_fare,
    'source', 'driver_tariff',
    'rate_profile_id', v_profile.id
  );
END;
$$;

REVOKE ALL ON FUNCTION private.fn_resolve_accept_fare_snapshot(
  uuid, numeric, numeric, numeric
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.trg_snapshot_fare_on_ride_accept()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_existing_fare numeric;
  v_snapshot jsonb;
  v_fare numeric;
BEGIN
  IF OLD.status::text IS DISTINCT FROM 'pending'
     OR NEW.status::text IS DISTINCT FROM 'accepted'
     OR NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Match HeyCabyRideFare.resolveEuroFromRow after the released Driver app's
  -- local enrichment: preserve an existing authoritative amount first.
  v_existing_fare := COALESCE(
    NULLIF(NEW.final_fare, 0),
    NULLIF(NEW.quoted_fare, 0),
    NULLIF(NEW.offered_fare, 0),
    NULLIF(NEW.marketplace_offered_fare, 0),
    NULLIF(NEW.estimated_fare, 0)
  );

  v_snapshot := private.fn_resolve_accept_fare_snapshot(
    NEW.driver_id,
    v_existing_fare,
    NEW.estimated_distance_km,
    NEW.estimated_duration_min
  );
  v_fare := NULLIF(v_snapshot ->> 'fare', '')::numeric;

  IF v_fare > 0 THEN
    NEW.offered_fare := v_fare;
    NEW.quoted_fare := v_fare;
    NEW.estimated_fare := v_fare;
  END IF;

  PERFORM public.fn_ride_audit_append(
    NEW.id,
    CASE
      WHEN v_fare > 0 THEN 'pricing.accept_fare_snapshotted'
      ELSE 'pricing.accept_fare_snapshot_missing'
    END,
    NEW.driver_id,
    v_snapshot || jsonb_build_object(
      'booking_mode', NEW.booking_mode,
      'distance_km', NEW.estimated_distance_km,
      'duration_min', NEW.estimated_duration_min
    ),
    'driver',
    'database_trigger',
    NEW.id
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_snapshot_fare_on_ride_accept()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS accept_fare_snapshot_authority
  ON public.ride_requests;
CREATE TRIGGER accept_fare_snapshot_authority
BEFORE UPDATE OF status, driver_id ON public.ride_requests
FOR EACH ROW
EXECUTE FUNCTION private.trg_snapshot_fare_on_ride_accept();

COMMENT ON FUNCTION private.fn_resolve_accept_fare_snapshot(
  uuid, numeric, numeric, numeric
) IS
  'Canonical accept-time fare resolver. Preserves existing quotes; otherwise applies the accepting Driver active tariff.';

COMMENT ON TRIGGER accept_fare_snapshot_authority ON public.ride_requests IS
  'Freezes one backend-owned fare snapshot in the atomic pending-to-accepted transition.';
