-- Read-only production-safe structural assertions for masked ride calling.
BEGIN;

DO $verify$
DECLARE definition text;
BEGIN
  IF has_table_privilege('anon','public.ride_call_attempts','SELECT')
     OR has_table_privilege('authenticated','public.ride_call_attempts','SELECT')
     OR has_table_privilege('authenticated','public.twilio_number_pool','SELECT') THEN
    RAISE EXCEPTION 'masked calling tables leaked to a client role';
  END IF;
  IF has_function_privilege('anon','public.fn_ride_communication_permissions(uuid)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.fn_ride_communication_permissions(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'communication permission grants invalid';
  END IF;
  IF has_function_privilege('authenticated','public.fn_masked_call_routing_context(uuid)','EXECUTE')
     OR has_function_privilege('authenticated','public.fn_update_masked_call_attempt(uuid,text,text,text,integer,numeric,text,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'service-only Twilio function leaked to authenticated';
  END IF;
  SELECT pg_get_functiondef('public.fn_ride_communication_permissions(uuid)'::regprocedure) INTO definition;
  IF definition NOT ILIKE '%driver_arrived%'
     OR definition NOT ILIKE '%post_ride_call_minutes%'
     OR definition NOT ILIKE '%post_ride_message_minutes%'
     OR definition NOT ILIKE '%ride_chat_blocks%'
     OR definition NOT ILIKE '%auth.uid()%' THEN
    RAISE EXCEPTION 'communication lifecycle authorization is incomplete';
  END IF;
  SELECT pg_get_functiondef('public.fn_create_masked_call_intent(uuid,uuid)'::regprocedure) INTO definition;
  IF definition NOT ILIKE '%FOR UPDATE SKIP LOCKED%'
     OR definition NOT ILIKE '%max_call_attempts_per_side%'
     OR definition NOT ILIKE '%ride_contact_attempts%'
     OR definition NOT ILIKE '%fn_ride_audit_append%'
     OR definition ILIKE '%p_destination%' THEN
    RAISE EXCEPTION 'call intent does not satisfy allocation/audit/client-input boundary';
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='ride_call_attempts'
      AND column_name IN ('from_phone','to_phone','rider_phone','driver_phone','real_phone')
  ) THEN
    RAISE EXCEPTION 'real phone number exists in client-adjacent call metadata';
  END IF;
END;
$verify$;

SELECT 'masked_ride_calling_contract_passed' AS result;
ROLLBACK;

