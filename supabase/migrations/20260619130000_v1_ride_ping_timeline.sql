-- Structured ping timeline for driver support UI + rider transparency.

CREATE OR REPLACE FUNCTION public.fn_ride_ping_timeline(p_ride_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR p_ride_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unauthorized');
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

REVOKE ALL ON FUNCTION public.fn_ride_ping_timeline(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_ride_ping_timeline(uuid) TO authenticated;
