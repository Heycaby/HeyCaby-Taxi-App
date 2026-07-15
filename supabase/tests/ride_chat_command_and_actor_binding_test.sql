-- Run after ride_chat_command_and_actor_binding. The harness wraps this in a
-- disposable PostgreSQL database; production smoke uses read-only checks.
BEGIN;

DO $verify$
DECLARE
  v_result jsonb;
  v_repeat jsonb;
  v_definition text;
  v_count bigint;
BEGIN
  IF has_function_privilege(
    'anon',
    'public.fn_send_ride_message(uuid,text,text,text)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.fn_send_ride_message(uuid,text,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'canonical chat command grants are incorrect';
  END IF;

  IF has_function_privilege(
    'anon', 'private.fn_ride_chat_actor(uuid)', 'EXECUTE'
  ) OR has_function_privilege(
    'authenticated', 'private.fn_ride_chat_actor(uuid)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'private chat actor resolver is exposed';
  END IF;

  IF NOT has_function_privilege(
    'anon',
    'public.fn_ride_chat_block_participant(uuid,text,text,text,text)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.fn_ride_chat_report_participant(uuid,text,text,text,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'released moderation compatibility grants changed';
  END IF;

  SELECT pg_get_functiondef(
    'public.fn_send_ride_message(uuid,text,text,text)'::regprocedure
  ) INTO v_definition;
  IF v_definition NOT ILIKE '%private.fn_ride_chat_actor%'
     OR v_definition NOT ILIKE '%ON CONFLICT%client_idempotency_key%'
     OR v_definition NOT ILIKE '%chat.message_sent%'
     OR v_definition NOT ILIKE '%ride_chat_blocks%' THEN
    RAISE EXCEPTION 'canonical send command is missing required invariants';
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
    AND schemaname = 'public'
    AND tablename = 'messages';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'messages publication membership count is %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_trigger
  WHERE tgrelid = 'public.messages'::regclass
    AND tgname = 'driver_agent_on_messages'
    AND NOT tgisinternal
    AND tgenabled <> 'D';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'chat notification trigger count is %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'messages'
    AND policyname IN (
      'messages_insert_participant',
      'messages_select_participant',
      'messages_recipient_marks_read'
    )
    AND COALESCE(qual, '') || COALESCE(with_check, '')
      ILIKE '%SELECT auth.uid()%';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'only % message policies cache auth.uid()', v_count;
  END IF;

  PERFORM set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000011',
    true
  );
  v_result := public.fn_send_ride_message(
    '00000000-0000-0000-0000-000000000031',
    'rider-retry-key-00000001',
    'I am outside',
    'text'
  );
  v_repeat := public.fn_send_ride_message(
    '00000000-0000-0000-0000-000000000031',
    'rider-retry-key-00000001',
    'I am outside',
    'text'
  );
  IF v_result ->> 'code' IS DISTINCT FROM 'sent'
     OR v_repeat ->> 'code' IS DISTINCT FROM 'already_sent'
     OR v_result #>> '{message,id}' IS DISTINCT FROM
        v_repeat #>> '{message,id}'
     OR v_result #>> '{message,conversation_id}' IS DISTINCT FROM
        '00000000-0000-0000-0000-000000000041'
     OR v_result #>> '{message,sender_id}' IS DISTINCT FROM
        '00000000-0000-0000-0000-000000000021' THEN
    RAISE EXCEPTION 'idempotent Rider send failed: %, %', v_result, v_repeat;
  END IF;

  SELECT count(*) INTO v_count FROM public.messages
  WHERE client_idempotency_key = 'rider-retry-key-00000001';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'retry inserted % message rows', v_count;
  END IF;
  SELECT count(*) INTO v_count FROM public.ride_audit_log
  WHERE event = 'chat.message_sent';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'retry emitted % audit rows', v_count;
  END IF;

  v_result := public.fn_send_ride_message(
    '00000000-0000-0000-0000-000000000031',
    'rider-retry-key-00000001',
    'Different content',
    'text'
  );
  IF v_result ->> 'code' IS DISTINCT FROM 'idempotency_conflict' THEN
    RAISE EXCEPTION 'idempotency conflict was not rejected: %', v_result;
  END IF;

  PERFORM set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000099',
    true
  );
  v_result := public.fn_send_ride_message(
    '00000000-0000-0000-0000-000000000031',
    'outsider-key-000000000001',
    'Forged message',
    'text'
  );
  IF v_result ->> 'code' IS DISTINCT FROM 'not_participant' THEN
    RAISE EXCEPTION 'non-participant send was not rejected: %', v_result;
  END IF;

  PERFORM set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000012',
    true
  );
  v_result := public.fn_send_ride_message(
    '00000000-0000-0000-0000-000000000031',
    'driver-key-0000000000001',
    'Two minutes away',
    'text'
  );
  IF v_result ->> 'code' IS DISTINCT FROM 'sent'
     OR v_result #>> '{message,sender_id}' IS DISTINCT FROM
        '00000000-0000-0000-0000-000000000012' THEN
    RAISE EXCEPTION 'Driver send identity binding failed: %', v_result;
  END IF;

  v_result := public.fn_ride_chat_report_participant(
    '00000000-0000-0000-0000-000000000031',
    '00000000-0000-0000-0000-000000000012',
    'driver',
    '00000000-0000-0000-0000-000000000021',
    'rider',
    'test report'
  );
  IF v_result ->> 'success' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'auth-bound report failed: %', v_result;
  END IF;

  v_result := public.fn_ride_chat_block_participant(
    '00000000-0000-0000-0000-000000000031',
    '00000000-0000-0000-0000-000000000012',
    'driver',
    '00000000-0000-0000-0000-000000000021',
    'rider'
  );
  IF v_result ->> 'success' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'auth-bound block failed: %', v_result;
  END IF;

  v_result := public.fn_send_ride_message(
    '00000000-0000-0000-0000-000000000031',
    'blocked-key-000000000001',
    'Must not send',
    'text'
  );
  IF v_result ->> 'code' IS DISTINCT FROM 'chat_blocked' THEN
    RAISE EXCEPTION 'block did not stop canonical send: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '', true);
  v_result := public.fn_ride_chat_report_participant(
    '00000000-0000-0000-0000-000000000031',
    '00000000-0000-0000-0000-000000000012',
    'driver',
    '00000000-0000-0000-0000-000000000021',
    'rider',
    'anonymous forgery'
  );
  IF v_result ->> 'error' IS DISTINCT FROM 'unauthorized' THEN
    RAISE EXCEPTION 'anonymous moderation call did not fail closed: %', v_result;
  END IF;
END;
$verify$;

SELECT 'ride_chat_command_and_actor_binding_passed' AS result;

ROLLBACK;
