-- fn_create_rider_session historically inserted rider_sessions without user_id and many
-- rider_identities rows never got user_id set — deletion by auth.uid() alone returned
-- identity_not_found. This adds: email match to auth.users, optional p_rider_identity_id
-- (verified), ride_requests token match, and deletes rider_sessions by session_token.

-- Remove single-argument overload so PostgREST always resolves the new signature.
DROP FUNCTION IF EXISTS public.fn_delete_rider_account(text);

CREATE OR REPLACE FUNCTION public.fn_delete_rider_account(
  p_session_token text,
  p_rider_identity_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_session uuid;
  v_auth_uid uuid;
  v_identity uuid;
  v_user_email text;
BEGIN
  IF p_session_token IS NULL OR length(trim(p_session_token)) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_token');
  END IF;

  SELECT rs.user_id
  INTO v_from_session
  FROM public.rider_sessions rs
  WHERE rs.session_token = trim(p_session_token)
  LIMIT 1;

  IF auth.uid() IS NOT NULL THEN
    v_auth_uid := auth.uid();
    SELECT u.email INTO v_user_email FROM auth.users u WHERE u.id = v_auth_uid LIMIT 1;
    IF v_from_session IS NOT NULL AND v_from_session IS DISTINCT FROM v_auth_uid THEN
      RETURN jsonb_build_object('success', false, 'error', 'token_user_mismatch');
    END IF;
  ELSE
    v_auth_uid := v_from_session;
  END IF;

  -- Anonymous: token must exist in rider_sessions (row may have user_id NULL).
  IF auth.uid() IS NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.rider_sessions rs WHERE rs.session_token = trim(p_session_token)
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
    END IF;
  END IF;

  -- 1) Direct link auth user → identity
  IF auth.uid() IS NOT NULL THEN
    SELECT ri.id INTO v_identity
    FROM public.rider_identities ri
    WHERE ri.user_id = auth.uid()
    LIMIT 1;
  END IF;

  -- 2) Same email as Auth (common when user_id was never backfilled on rider_identities)
  IF v_identity IS NULL AND auth.uid() IS NOT NULL AND v_user_email IS NOT NULL THEN
    SELECT ri.id INTO v_identity
    FROM public.rider_identities ri
    WHERE ri.email IS NOT NULL
      AND lower(trim(ri.email)) = lower(trim(v_user_email))
    LIMIT 1;
  END IF;

  -- 3) Client-supplied identity id (must pass ownership checks)
  IF v_identity IS NULL AND p_rider_identity_id IS NOT NULL THEN
    SELECT ri.id INTO v_identity
    FROM public.rider_identities ri
    WHERE ri.id = p_rider_identity_id
      AND (
        ri.user_id = auth.uid()
        OR (
          auth.uid() IS NOT NULL
          AND v_user_email IS NOT NULL
          AND ri.email IS NOT NULL
          AND lower(trim(ri.email)) = lower(trim(v_user_email))
        )
        OR EXISTS (
          SELECT 1
          FROM public.ride_requests rr
          WHERE rr.rider_identity_id = ri.id
            AND rr.rider_token = trim(p_session_token)
        )
      )
    LIMIT 1;
  END IF;

  -- 4) JWT + identity id from app when the row never had user_id set (or it already matches)
  IF v_identity IS NULL AND auth.uid() IS NOT NULL AND p_rider_identity_id IS NOT NULL THEN
    SELECT ri.id INTO v_identity
    FROM public.rider_identities ri
    WHERE ri.id = p_rider_identity_id
      AND (ri.user_id IS NULL OR ri.user_id = auth.uid());
  END IF;

  -- 5) Anonymous: identity linked via past ride_requests using the same device token
  IF v_identity IS NULL AND auth.uid() IS NULL THEN
    SELECT rr.rider_identity_id INTO v_identity
    FROM public.ride_requests rr
    WHERE rr.rider_token = trim(p_session_token)
      AND rr.rider_identity_id IS NOT NULL
    ORDER BY rr.created_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  IF v_identity IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'identity_not_found');
  END IF;

  DELETE FROM public.driver_notify_queue
  WHERE rider_identity_id = v_identity;

  DELETE FROM public.rider_rating_credibility
  WHERE rider_identity_id = v_identity;

  DELETE FROM public.rider_sessions
  WHERE session_token = trim(p_session_token)
     OR (v_auth_uid IS NOT NULL AND user_id IS NOT DISTINCT FROM v_auth_uid);

  DELETE FROM public.rider_identities
  WHERE id = v_identity;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_delete_rider_account(text, uuid) TO anon, authenticated;
