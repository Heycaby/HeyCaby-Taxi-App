-- Fold Driver ping timeline truth into the canonical Rider ride projection so
-- clients do not poll a second RPC or infer delivery from local timers.

CREATE OR REPLACE FUNCTION public.fn_rider_ride_snapshot(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_result jsonb;
  v_booking_mode text;
  v_driver_on_my_way_at timestamptz;
BEGIN
  v_result := private.fn_rider_ride_snapshot_base(
    p_ride_request_id,
    p_rider_token
  );

  IF COALESCE((v_result ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  SELECT rr.booking_mode
  INTO v_booking_mode
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  SELECT max(ral.occurred_at)
  INTO v_driver_on_my_way_at
  FROM public.ride_audit_log ral
  WHERE ral.ride_id = p_ride_request_id
    AND (
      ral.event = 'driver.ping_on_my_way'
      OR ral.event LIKE 'driver.ping_on_my_way.%'
      OR ral.event = 'driver.ping_nearby'
      OR ral.event LIKE 'driver.ping_nearby.%'
    );

  RETURN v_result || jsonb_build_object(
    'booking_mode', v_booking_mode,
    'driver_on_my_way', v_driver_on_my_way_at IS NOT NULL,
    'driver_on_my_way_at', v_driver_on_my_way_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_ride_snapshot(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_ride_snapshot(uuid, text)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_rider_ride_snapshot(uuid, text) IS
  'Versioned Rider lifecycle, payment, route, fare, waiting, booking-mode, and Driver-ping projection.';

NOTIFY pgrst, 'reload schema';
