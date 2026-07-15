-- Production history 20260713134807. Add booking presentation data without copying the lifecycle resolver. The
-- original implementation becomes private; this public function is a thin
-- compatibility/projection wrapper.

ALTER FUNCTION public.fn_rider_ride_snapshot(uuid, text)
  RENAME TO fn_rider_ride_snapshot_base;
ALTER FUNCTION public.fn_rider_ride_snapshot_base(uuid, text)
  SET SCHEMA private;

REVOKE ALL ON FUNCTION private.fn_rider_ride_snapshot_base(uuid, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_rider_ride_snapshot(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_result jsonb;
  v_booking_mode text;
BEGIN
  v_result := private.fn_rider_ride_snapshot_base(
    p_ride_request_id,
    p_rider_token
  );

  IF COALESCE((v_result->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  SELECT rr.booking_mode
  INTO v_booking_mode
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id;

  RETURN v_result || jsonb_build_object('booking_mode', v_booking_mode);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_ride_snapshot(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_ride_snapshot(uuid, text)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_rider_ride_snapshot(uuid, text) IS
  'Versioned Rider ride projection; thin wrapper around the private canonical lifecycle resolver.';

NOTIFY pgrst, 'reload schema';
