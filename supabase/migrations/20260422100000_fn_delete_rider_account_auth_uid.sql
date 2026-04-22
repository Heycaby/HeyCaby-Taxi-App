-- Rider account deletion: support Supabase JWT when rider_sessions row is missing/out of sync.
-- Previous logic only resolved the user via rider_sessions.session_token; email riders with a
-- valid session cookie but no (or stale) rider_sessions row got session_not_found and could
-- not delete in-app.
--
-- Rules:
-- * If auth.uid() is set: delete data for that user only. If the token also matches a
--   rider_sessions row, it must be the same user_id (prevents using another user's token
--   while logged in as someone else).
-- * If auth.uid() is null (anonymous token-only client): require rider_sessions match (unchanged).

CREATE OR REPLACE FUNCTION public.fn_delete_rider_account(p_session_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_session uuid;
  v_auth_uid uuid;
  v_identity uuid;
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
    IF v_from_session IS NOT NULL AND v_from_session IS DISTINCT FROM v_auth_uid THEN
      RETURN jsonb_build_object('success', false, 'error', 'token_user_mismatch');
    END IF;
  ELSE
    v_auth_uid := v_from_session;
  END IF;

  IF v_auth_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  SELECT ri.id
  INTO v_identity
  FROM public.rider_identities ri
  WHERE ri.user_id = v_auth_uid
  LIMIT 1;

  IF v_identity IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'identity_not_found');
  END IF;

  DELETE FROM public.driver_notify_queue
  WHERE rider_identity_id = v_identity;

  DELETE FROM public.rider_rating_credibility
  WHERE rider_identity_id = v_identity;

  DELETE FROM public.rider_sessions
  WHERE user_id = v_auth_uid;

  DELETE FROM public.rider_identities
  WHERE id = v_identity;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
