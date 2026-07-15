-- One authenticated command for Rider <-> Driver chat. Released direct table
-- inserts and moderation RPC signatures remain available for compatibility,
-- but every path is now bound to the authenticated ride participant.

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS client_idempotency_key text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.messages'::regclass
      AND conname = 'messages_client_idempotency_key_length'
  ) THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_client_idempotency_key_length
      CHECK (
        client_idempotency_key IS NULL
        OR length(client_idempotency_key) BETWEEN 16 AND 128
      );
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS messages_sender_idempotency_uidx
  ON public.messages (
    ride_request_id,
    sender_type,
    sender_id,
    client_idempotency_key
  )
  WHERE client_idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS messages_ride_created_id_idx
  ON public.messages (ride_request_id, created_at, id);

UPDATE public.messages m
SET conversation_id = c.id
FROM public.conversations c
WHERE m.conversation_id IS NULL
  AND c.ride_request_id = m.ride_request_id;

CREATE OR REPLACE FUNCTION private.fn_ride_chat_actor(p_ride_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ride public.ride_requests%ROWTYPE;
  v_driver_id uuid;
  v_sender_id uuid;
  v_peer_id uuid;
  v_sender_type text;
  v_conversation_id uuid;
BEGIN
  IF v_uid IS NULL OR p_ride_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT rr.*
  INTO v_ride
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT d.id
  INTO v_driver_id
  FROM public.drivers d
  WHERE d.user_id = v_uid
  LIMIT 1;

  IF v_driver_id IS NOT NULL AND v_ride.driver_id = v_driver_id THEN
    v_sender_type := 'driver';
    v_sender_id := v_uid;
    v_peer_id := COALESCE(v_ride.rider_identity_id, v_ride.rider_id);
  ELSIF v_ride.rider_id = v_uid
     OR EXISTS (
       SELECT 1
       FROM public.rider_identities ri
       WHERE ri.id = v_ride.rider_identity_id
         AND ri.user_id = v_uid
     )
     OR EXISTS (
       SELECT 1
       FROM public.rider_sessions rs
       WHERE rs.user_id = v_uid
         AND rs.session_token = v_ride.rider_token
     ) THEN
    v_sender_type := 'rider';
    v_sender_id := COALESCE(v_ride.rider_identity_id, v_uid);
    SELECT d.user_id
    INTO v_peer_id
    FROM public.drivers d
    WHERE d.id = v_ride.driver_id;
  ELSE
    RETURN NULL;
  END IF;

  SELECT c.id
  INTO v_conversation_id
  FROM public.conversations c
  WHERE c.ride_request_id = p_ride_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'sender_type', v_sender_type,
    'sender_id', v_sender_id,
    'peer_id', v_peer_id,
    'ride_status', v_ride.status,
    'conversation_id', v_conversation_id
  );
END;
$$;

REVOKE ALL ON FUNCTION private.fn_ride_chat_actor(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_send_ride_message(
  p_ride_id uuid,
  p_idempotency_key text,
  p_content text,
  p_message_type text DEFAULT 'text'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_actor jsonb;
  v_sender_type text;
  v_sender_id uuid;
  v_status text;
  v_content text;
  v_message_type text;
  v_key text;
  v_conversation_id uuid;
  v_message public.messages%ROWTYPE;
  v_inserted boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized');
  END IF;

  v_content := btrim(COALESCE(p_content, ''));
  v_message_type := lower(btrim(COALESCE(p_message_type, 'text')));
  v_key := btrim(COALESCE(p_idempotency_key, ''));

  IF p_ride_id IS NULL
     OR length(v_content) < 1
     OR length(v_content) > 2000
     OR v_message_type NOT IN ('text', 'ping')
     OR v_key !~ '^[A-Za-z0-9_-]{16,128}$' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_message');
  END IF;

  v_actor := private.fn_ride_chat_actor(p_ride_id);
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_participant');
  END IF;

  v_sender_type := v_actor ->> 'sender_type';
  v_sender_id := (v_actor ->> 'sender_id')::uuid;
  v_status := v_actor ->> 'ride_status';
  v_conversation_id := NULLIF(v_actor ->> 'conversation_id', '')::uuid;

  IF v_status NOT IN (
    'accepted',
    'assigned',
    'driver_found',
    'driver_en_route',
    'arrived',
    'driver_arrived',
    'in_progress'
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'ride_chat_closed',
      'ride_status', v_status
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.ride_chat_blocks b
    WHERE b.ride_id = p_ride_id
      AND (
        (b.blocker_type = v_sender_type AND b.blocker_id = v_sender_id::text)
        OR
        (b.blocked_type = v_sender_type AND b.blocked_id = v_sender_id::text)
      )
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'chat_blocked');
  END IF;

  INSERT INTO public.messages (
    ride_request_id,
    conversation_id,
    sender_type,
    sender_id,
    content,
    message_type,
    client_idempotency_key
  )
  VALUES (
    p_ride_id,
    v_conversation_id,
    v_sender_type,
    v_sender_id,
    v_content,
    v_message_type,
    v_key
  )
  ON CONFLICT (
    ride_request_id,
    sender_type,
    sender_id,
    client_idempotency_key
  ) WHERE client_idempotency_key IS NOT NULL
  DO NOTHING
  RETURNING * INTO v_message;

  v_inserted := FOUND;
  IF NOT v_inserted THEN
    SELECT m.*
    INTO v_message
    FROM public.messages m
    WHERE m.ride_request_id = p_ride_id
      AND m.sender_type = v_sender_type
      AND m.sender_id = v_sender_id
      AND m.client_idempotency_key = v_key;

    IF NOT FOUND
       OR v_message.content IS DISTINCT FROM v_content
       OR v_message.message_type IS DISTINCT FROM v_message_type THEN
      RETURN jsonb_build_object('ok', false, 'code', 'idempotency_conflict');
    END IF;
  END IF;

  IF v_inserted THEN
    PERFORM public.fn_ride_audit_append(
      p_ride_id,
      'chat.message_sent',
      v_sender_id,
      jsonb_build_object(
        'message_id', v_message.id,
        'message_type', v_message_type,
        'conversation_id', v_message.conversation_id
      ),
      v_sender_type,
      'rpc',
      v_message.id
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN v_inserted THEN 'sent' ELSE 'already_sent' END,
    'message', to_jsonb(v_message)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_send_ride_message(uuid, text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_send_ride_message(uuid, text, text, text)
  TO authenticated;

-- Released direct-insert clients remain compatible, but cannot bypass a block.
DROP POLICY IF EXISTS messages_insert_participant ON public.messages;
CREATE POLICY messages_insert_participant
ON public.messages
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.ride_requests rr
    WHERE rr.id = messages.ride_request_id
      AND rr.status::text IN (
        'accepted',
        'assigned',
        'driver_found',
        'driver_en_route',
        'arrived',
        'driver_arrived',
        'in_progress'
      )
      AND (
        (
          messages.sender_type::text = 'driver'
          AND messages.sender_id = auth.uid()
          AND rr.driver_id IN (
            SELECT d.id
            FROM public.drivers d
            WHERE d.user_id = auth.uid()
          )
        )
        OR
        (
          messages.sender_type::text = 'rider'
          AND (
            rr.rider_id = auth.uid()
            OR rr.rider_identity_id IN (
              SELECT ri.id
              FROM public.rider_identities ri
              WHERE ri.user_id = auth.uid()
            )
            OR rr.rider_token IN (
              SELECT rs.session_token
              FROM public.rider_sessions rs
              WHERE rs.user_id = auth.uid()
            )
          )
          AND (
            messages.sender_id = auth.uid()
            OR messages.sender_id = rr.rider_identity_id
          )
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.ride_chat_blocks b
    WHERE b.ride_id = messages.ride_request_id
      AND (
        (
          b.blocker_type = messages.sender_type::text
          AND b.blocker_id = messages.sender_id::text
        )
        OR
        (
          b.blocked_type = messages.sender_type::text
          AND b.blocked_id = messages.sender_id::text
        )
      )
  )
);

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
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_actor jsonb;
  v_actor_id text;
  v_actor_type text;
BEGIN
  v_actor := private.fn_ride_chat_actor(p_ride_id);
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  v_actor_id := v_actor ->> 'sender_id';
  v_actor_type := v_actor ->> 'sender_type';
  IF btrim(COALESCE(p_blocker_id, '')) <> v_actor_id
     OR p_blocker_type IS DISTINCT FROM v_actor_type
     OR p_blocked_type NOT IN ('rider', 'driver')
     OR p_blocked_type = v_actor_type
     OR btrim(COALESCE(p_blocked_id, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_participant');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.ride_request_id = p_ride_id
      AND m.sender_id::text = btrim(p_blocked_id)
      AND m.sender_type::text = p_blocked_type
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'peer_not_in_ride');
  END IF;

  INSERT INTO public.ride_chat_blocks (
    ride_id, blocker_id, blocker_type, blocked_id, blocked_type
  )
  VALUES (
    p_ride_id, v_actor_id, v_actor_type,
    btrim(p_blocked_id), p_blocked_type
  )
  ON CONFLICT ON CONSTRAINT ride_chat_blocks_ride_blocker_blocked_unique
  DO NOTHING;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_ride_chat_list_blocks(
  p_ride_id uuid,
  p_blocker_id text,
  p_blocker_type text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_actor jsonb;
BEGIN
  v_actor := private.fn_ride_chat_actor(p_ride_id);
  IF v_actor IS NULL
     OR btrim(COALESCE(p_blocker_id, '')) <> (v_actor ->> 'sender_id')
     OR p_blocker_type IS DISTINCT FROM (v_actor ->> 'sender_type') THEN
    RETURN '[]'::jsonb;
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'blocked_id', b.blocked_id,
        'blocked_type', b.blocked_type
      )
      ORDER BY b.created_at, b.id
    )
    FROM public.ride_chat_blocks b
    WHERE b.ride_id = p_ride_id
      AND b.blocker_id = (v_actor ->> 'sender_id')
      AND b.blocker_type = (v_actor ->> 'sender_type')
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_ride_chat_report_participant(
  p_ride_id uuid,
  p_reporter_id text,
  p_reporter_type text,
  p_reported_id text,
  p_reported_type text,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $$
DECLARE
  v_actor jsonb;
  v_actor_id text;
  v_actor_type text;
BEGIN
  v_actor := private.fn_ride_chat_actor(p_ride_id);
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  v_actor_id := v_actor ->> 'sender_id';
  v_actor_type := v_actor ->> 'sender_type';
  IF btrim(COALESCE(p_reporter_id, '')) <> v_actor_id
     OR p_reporter_type IS DISTINCT FROM v_actor_type
     OR p_reported_type NOT IN ('rider', 'driver')
     OR p_reported_type = v_actor_type
     OR btrim(COALESCE(p_reported_id, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_participant');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.ride_request_id = p_ride_id
      AND m.sender_id::text = btrim(p_reported_id)
      AND m.sender_type::text = p_reported_type
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'peer_not_in_ride');
  END IF;

  INSERT INTO public.ride_chat_reports (
    ride_id, reporter_id, reporter_type, reported_id, reported_type, reason
  )
  VALUES (
    p_ride_id,
    v_actor_id,
    v_actor_type,
    btrim(p_reported_id),
    p_reported_type,
    NULLIF(left(btrim(COALESCE(p_reason, '')), 2000), '')
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Preserve released moderation function signatures and effective grants. An
-- unauthenticated call now fails closed inside each function.
GRANT EXECUTE ON FUNCTION public.fn_ride_chat_block_participant(
  uuid, text, text, text, text
) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_chat_list_blocks(uuid, text, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ride_chat_report_participant(
  uuid, text, text, text, text, text
) TO anon, authenticated;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_chat_source_event_uidx
  ON public.notifications (
    user_type,
    user_id,
    ((data ->> 'source_event_id'))
  )
  WHERE category = 'chat'
    AND NULLIF(data ->> 'source_event_id', '') IS NOT NULL;

COMMENT ON FUNCTION public.fn_send_ride_message(uuid, text, text, text) IS
  'Canonical idempotent Rider/Driver ride-chat send command; binds actor, ride, conversation, status, and block state server-side.';
