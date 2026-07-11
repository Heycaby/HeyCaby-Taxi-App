-- Wire ride reports to the driver who carried out the ride.
-- Add admin response columns so the backend can respond back to the rider.
-- Create fn_rider_submit_ride_report RPC that resolves driver_id from the ride.

-- 1. Add columns to ride_reports for driver/rider context and admin response.
ALTER TABLE public.ride_reports
  ADD COLUMN IF NOT EXISTS driver_id uuid REFERENCES public.drivers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS rider_identity_id uuid REFERENCES public.rider_identities(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS rider_token text,
  ADD COLUMN IF NOT EXISTS admin_response text,
  ADD COLUMN IF NOT EXISTS admin_responded_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolved boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';

-- Backfill driver_id for existing reports from the ride_requests table.
UPDATE public.ride_reports rr
  SET driver_id = sub.driver_id
  FROM (
    SELECT r.id AS ride_request_id, r.driver_id
    FROM public.ride_requests r
    WHERE r.driver_id IS NOT NULL
  ) sub
  WHERE rr.ride_request_id = sub.ride_request_id
    AND rr.driver_id IS NULL;

-- 2. RPC: rider submits a report for a completed ride.
--    Resolves driver_id from ride_requests so the report is tied to the driver.
CREATE OR REPLACE FUNCTION public.fn_rider_submit_ride_report(
  p_ride_request_id uuid,
  p_reason text,
  p_details text DEFAULT NULL,
  p_rider_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_authorized boolean := false;
  v_details text;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RETURN json_build_object('ok', false, 'error', 'missing_reason');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  -- Authorization: rider_identity user_id match.
  IF v_ride.rider_identity_id IS NOT NULL
     AND auth.uid() IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_identities ri
       WHERE ri.id = v_ride.rider_identity_id
         AND ri.user_id = auth.uid()
     ) THEN
    v_authorized := true;
  END IF;

  -- Authorization: rider_token match.
  IF NOT v_authorized
     AND p_rider_token IS NOT NULL
     AND btrim(p_rider_token) <> ''
     AND v_ride.rider_token = btrim(p_rider_token) THEN
    v_authorized := true;
  END IF;

  -- Authorization: session token match.
  IF NOT v_authorized
     AND auth.uid() IS NOT NULL
     AND v_ride.rider_token IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_sessions rs
       WHERE rs.user_id = auth.uid()
         AND rs.session_token IS NOT NULL
         AND btrim(rs.session_token) <> ''
         AND rs.session_token = v_ride.rider_token
     ) THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized THEN
    RETURN json_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  v_details := NULLIF(btrim(COALESCE(p_details, '')), '');

  UPDATE public.ride_reports rr
  SET
    reason = btrim(p_reason),
    details = COALESCE(v_details, rr.details),
    status = 'pending',
    resolved = false,
    is_reviewed = false,
    driver_id = COALESCE(rr.driver_id, v_ride.driver_id),
    rider_identity_id = COALESCE(rr.rider_identity_id, v_ride.rider_identity_id),
    rider_token = COALESCE(rr.rider_token, v_ride.rider_token)
  WHERE rr.ride_request_id = p_ride_request_id
    AND rr.reporter_type = 'rider';

  IF NOT FOUND THEN
    INSERT INTO public.ride_reports (
      ride_request_id,
      reporter_type,
      driver_id,
      rider_identity_id,
      rider_token,
      reason,
      details,
      status,
      resolved,
      is_reviewed
    )
    VALUES (
      p_ride_request_id,
      'rider',
      v_ride.driver_id,
      v_ride.rider_identity_id,
      v_ride.rider_token,
      btrim(p_reason),
      v_details,
      'pending',
      false,
      false
    );
  END IF;

  RETURN json_build_object(
    'ok', true,
    'ride_id', p_ride_request_id,
    'driver_id', v_ride.driver_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_submit_ride_report(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_submit_ride_report(uuid, text, text, text) TO authenticated;

-- 3. RPC: rider fetches admin responses for their reports on a ride.
CREATE OR REPLACE FUNCTION public.fn_rider_get_report_responses(
  p_ride_request_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ride public.ride_requests%ROWTYPE;
  v_authorized boolean := false;
  v_reports jsonb;
BEGIN
  IF p_ride_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  IF v_ride.rider_identity_id IS NOT NULL
     AND auth.uid() IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_identities ri
       WHERE ri.id = v_ride.rider_identity_id
         AND ri.user_id = auth.uid()
     ) THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized
     AND p_rider_token IS NOT NULL
     AND btrim(p_rider_token) <> ''
     AND v_ride.rider_token = btrim(p_rider_token) THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized
     AND auth.uid() IS NOT NULL
     AND v_ride.rider_token IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.rider_sessions rs
       WHERE rs.user_id = auth.uid()
         AND rs.session_token IS NOT NULL
         AND btrim(rs.session_token) <> ''
         AND rs.session_token = v_ride.rider_token
     ) THEN
    v_authorized := true;
  END IF;

  IF NOT v_authorized THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', rr.id,
        'reason', rr.reason,
        'details', rr.details,
        'status', rr.status,
        'resolved', rr.resolved,
        'admin_response', rr.admin_response,
        'admin_responded_at', rr.admin_responded_at,
        'created_at', rr.created_at
      )
      ORDER BY rr.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_reports
  FROM public.ride_reports rr
  WHERE rr.ride_request_id = p_ride_request_id
    AND rr.reporter_type = 'rider';

  RETURN jsonb_build_object('ok', true, 'reports', v_reports);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_get_report_responses(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_rider_get_report_responses(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_rider_submit_ride_report(uuid, text, text, text) IS
  'Rider submits a ride report; driver_id is resolved from the ride so backend can address it with the driver.';
COMMENT ON FUNCTION public.fn_rider_get_report_responses(uuid, text) IS
  'Rider fetches admin responses for reports on a specific ride.';
