-- App Store: account deletion (Guideline 5.1.1(v)) + ride chat block list (user-to-user messaging).
-- Apply with: supabase db push / SQL Editor.
--
-- Rider deletion: rider_sessions.user_id → auth.users; rider_identities.user_id → same auth user.
-- Auth (driver): enable "Allow users to delete their own account" in Supabase Dashboard → Authentication
--   (or equivalent) so DELETE /auth/v1/user succeeds from the client after fn_delete_driver_owned_data.

-- ---------------------------------------------------------------------------
-- Ride chat blocks (server-side; clients call RPCs only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ride_chat_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  ride_id uuid NOT NULL,
  blocker_id text NOT NULL,
  blocker_type text NOT NULL CHECK (blocker_type IN ('rider', 'driver')),
  blocked_id text NOT NULL,
  blocked_type text NOT NULL CHECK (blocked_type IN ('rider', 'driver')),
  CONSTRAINT ride_chat_blocks_ride_blocker_blocked_unique UNIQUE (ride_id, blocker_id, blocked_id)
);

ALTER TABLE public.ride_chat_blocks ENABLE ROW LEVEL SECURITY;

-- No policies: direct table access denied; SECURITY DEFINER RPCs below bypass RLS as owner.

CREATE OR REPLACE FUNCTION public.fn_ride_chat_block_participant(
  p_ride_id uuid,
  p_blocker_id text,
  p_blocker_type text,
  p_blocked_id text,
  p_blocked_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_ride_id IS NULL
     OR p_blocker_id IS NULL OR length(trim(p_blocker_id)) = 0
     OR p_blocked_id IS NULL OR length(trim(p_blocked_id)) = 0
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_params');
  END IF;

  IF p_blocker_type NOT IN ('rider', 'driver') OR p_blocked_type NOT IN ('rider', 'driver') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_role');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.ride_request_id = p_ride_id
      AND m.sender_id::text = trim(p_blocker_id)
      AND m.sender_type = p_blocker_type
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'blocker_not_in_ride');
  END IF;

  INSERT INTO public.ride_chat_blocks (
    ride_id, blocker_id, blocker_type, blocked_id, blocked_type
  )
  VALUES (
    p_ride_id, p_blocker_id, p_blocker_type, p_blocked_id, p_blocked_type
  )
  ON CONFLICT ON CONSTRAINT ride_chat_blocks_ride_blocker_blocked_unique DO NOTHING;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_ride_chat_list_blocks(
  p_ride_id uuid,
  p_blocker_id text,
  p_blocker_type text
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'blocked_id', b.blocked_id,
        'blocked_type', b.blocked_type
      )
    ),
    '[]'::jsonb
  )
  FROM public.ride_chat_blocks b
  WHERE b.ride_id = p_ride_id
    AND b.blocker_id = p_blocker_id
    AND b.blocker_type = p_blocker_type
    AND EXISTS (
      SELECT 1
      FROM public.messages m
      WHERE m.ride_request_id = p_ride_id
        AND m.sender_id::text = trim(p_blocker_id)
        AND m.sender_type = p_blocker_type
    );
$$;

-- ---------------------------------------------------------------------------
-- Driver: delete application row before Auth user deletion (client calls both)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_delete_driver_owned_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  DELETE FROM public.drivers
  WHERE user_id = v_uid;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ---------------------------------------------------------------------------
-- Rider: delete identity using session token (matches rider_token in app storage)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_delete_rider_account(p_session_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_identity uuid;
BEGIN
  IF p_session_token IS NULL OR length(trim(p_session_token)) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_token');
  END IF;

  SELECT rs.user_id
  INTO v_auth_uid
  FROM public.rider_sessions rs
  WHERE rs.session_token = trim(p_session_token)
  LIMIT 1;

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

GRANT EXECUTE ON FUNCTION public.fn_ride_chat_block_participant(uuid, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_chat_list_blocks(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_delete_driver_owned_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_delete_rider_account(text) TO anon, authenticated;
