-- Allow guest riders (rider_token) to read driver ping timeline for on-my-way UI.

DROP FUNCTION IF EXISTS public.fn_ride_ping_timeline(uuid);

CREATE OR REPLACE FUNCTION public.fn_ride_ping_timeline(
  p_ride_id uuid,
  p_rider_token text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_token text := NULLIF(btrim(p_rider_token), '');
BEGIN
  IF p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_ride_id');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    JOIN public.drivers d ON d.id = rr.driver_id
    WHERE rr.id = p_ride_id
      AND d.user_id = v_uid
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    JOIN public.rider_identities ri ON ri.id = rr.rider_identity_id
    WHERE rr.id = p_ride_id
      AND ri.user_id = v_uid
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = p_ride_id
      AND v_token IS NOT NULL
      AND (
        rr.rider_token = v_token
        OR EXISTS (
          SELECT 1
          FROM public.rider_sessions rs
          WHERE rs.session_token = v_token
            AND rr.rider_token = rs.session_token
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.admin_users au WHERE au.user_id = v_uid
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'forbidden');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'event', ral.event,
          'occurred_at', ral.occurred_at,
          'metadata', ral.metadata
        )
        ORDER BY ral.occurred_at DESC
      )
      FROM public.ride_audit_log ral
      WHERE ral.ride_id = p_ride_id
        AND ral.event LIKE 'driver.ping_%'
      LIMIT 100
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_ride_ping_timeline(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ride_ping_timeline(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_ping_timeline(uuid, text) TO anon;

COMMENT ON FUNCTION public.fn_ride_ping_timeline(uuid, text) IS
  'Driver/rider/admin ping timeline; optional rider_token for guest session reads.';
