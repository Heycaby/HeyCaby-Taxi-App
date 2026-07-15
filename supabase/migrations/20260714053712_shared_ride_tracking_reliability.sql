-- Shared Ride Tracking is owned by Rider Experience. Supabase remains the
-- authority for token lifecycle and ride state; the public web client only
-- renders the projection returned by get-shared-ride.

-- A ride may have only one active public capability token. Row locking in the
-- RPC below serializes concurrent share attempts; this index is the final
-- integrity guard.
CREATE UNIQUE INDEX IF NOT EXISTS ride_shares_one_active_per_ride_idx
ON public.ride_shares (ride_request_id)
WHERE is_active = true;

CREATE OR REPLACE FUNCTION public.fn_rider_create_share_token(
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
  v_share_token text;
  v_expires_at timestamptz;
  v_created boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ride_not_found');
  END IF;

  -- Keep the legacy parameter in the signature for released app versions, but
  -- never use a bearer rider_token as authorization. Ownership is auth-bound.
  IF NOT (
    v_ride.rider_identity_id IN (
      SELECT ri.id
      FROM public.rider_identities ri
      WHERE ri.user_id = auth.uid()
    )
    OR v_ride.rider_token IN (
      SELECT rs.session_token
      FROM public.rider_sessions rs
      WHERE rs.user_id = auth.uid()
    )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authorized');
  END IF;

  IF v_ride.status::text NOT IN (
    'assigned', 'accepted', 'driver_found', 'driver_en_route',
    'driver_arrived', 'arrived', 'in_progress'
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'ride_not_trackable',
      'status', v_ride.status
    );
  END IF;

  -- Expired rows must not permanently poison future share attempts.
  UPDATE public.ride_shares
  SET is_active = false
  WHERE ride_request_id = p_ride_request_id
    AND is_active = true
    AND expires_at <= now();

  SELECT rs.share_token, rs.expires_at
  INTO v_share_token, v_expires_at
  FROM public.ride_shares rs
  WHERE rs.ride_request_id = p_ride_request_id
    AND rs.is_active = true
    AND rs.expires_at > now()
  ORDER BY rs.created_at DESC
  LIMIT 1;

  IF v_share_token IS NULL THEN
    INSERT INTO public.ride_shares (
      ride_request_id,
      rider_token,
      is_active,
      expires_at
    ) VALUES (
      p_ride_request_id,
      COALESCE(v_ride.rider_token, auth.uid()::text),
      true,
      now() + interval '24 hours'
    )
    RETURNING share_token, expires_at
    INTO v_share_token, v_expires_at;

    v_created := true;

    INSERT INTO public.ride_audit_log (
      ride_id,
      event,
      actor_id,
      actor_type,
      source,
      metadata
    ) VALUES (
      p_ride_request_id,
      'ride.share_created',
      auth.uid(),
      'rider',
      'rider_app',
      jsonb_build_object('expires_at', v_expires_at)
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'share_token', v_share_token,
    'share_url', '/track/' || v_share_token,
    'expires_at', v_expires_at,
    'created', v_created
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_rider_create_share_token(uuid, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_create_share_token(uuid, text)
TO authenticated;

COMMENT ON FUNCTION public.fn_rider_create_share_token(uuid, text) IS
'Creates or reuses the single unexpired shared-ride capability token for an auth-bound rider. p_rider_token is retained only for released-client signature compatibility.';
