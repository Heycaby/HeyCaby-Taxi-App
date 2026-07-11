-- Human rider support must remain separate from Yaz AI support. These RPCs
-- provide atomic, owner-checked writes while preserving the existing tickets
-- table and Realtime readers.

create or replace function public.fn_rider_support_create_ticket(
  p_category text,
  p_content text
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_category text := lower(btrim(coalesce(p_category, '')));
  v_content text := btrim(coalesce(p_content, ''));
  v_ticket_id uuid;
  v_now timestamptz := clock_timestamp();
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if v_category not in ('ride_issue', 'payment', 'account', 'other') then
    raise exception using errcode = '22023', message = 'invalid_support_category';
  end if;

  if char_length(v_content) < 1 or char_length(v_content) > 2000 then
    raise exception using errcode = '22023', message = 'invalid_support_message';
  end if;

  insert into public.tickets (
    user_type,
    user_id,
    category,
    priority,
    status,
    messages,
    ai_handled,
    last_message_at,
    message_count,
    created_at,
    updated_at
  ) values (
    'rider',
    v_user_id::text,
    v_category,
    'normal',
    'open',
    jsonb_build_array(jsonb_build_object(
      'role', 'user',
      'sender_type', 'rider',
      'content', v_content,
      'ts', v_now
    )),
    false,
    v_now,
    1,
    v_now,
    v_now
  )
  returning id into v_ticket_id;

  return v_ticket_id;
end;
$$;

create or replace function public.fn_rider_support_append_message(
  p_ticket_id uuid,
  p_content text
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_content text := btrim(coalesce(p_content, ''));
  v_ticket public.tickets%rowtype;
  v_message jsonb;
  v_now timestamptz := clock_timestamp();
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if p_ticket_id is null then
    raise exception using errcode = '22023', message = 'ticket_required';
  end if;

  if char_length(v_content) < 1 or char_length(v_content) > 2000 then
    raise exception using errcode = '22023', message = 'invalid_support_message';
  end if;

  select *
    into v_ticket
    from public.tickets
   where id = p_ticket_id
   for update;

  if not found
     or v_ticket.user_type <> 'rider'
     or v_ticket.user_id <> v_user_id::text then
    raise exception using errcode = '42501', message = 'ticket_not_accessible';
  end if;

  if v_ticket.ai_handled then
    raise exception using errcode = '22023', message = 'ai_ticket_requires_yaz_service';
  end if;

  v_message := jsonb_build_object(
    'role', 'user',
    'sender_type', 'rider',
    'content', v_content,
    'ts', v_now
  );

  update public.tickets
     set messages = coalesce(messages, '[]'::jsonb) || jsonb_build_array(v_message),
         status = 'open',
         resolved_at = null,
         resolved_by = null,
         resolution_summary = null,
         resolution_outcome = null,
         last_message_at = v_now,
         message_count = coalesce(message_count, 0) + 1,
         updated_at = v_now
   where id = p_ticket_id;

  return jsonb_build_object(
    'ok', true,
    'ticket_id', p_ticket_id,
    'status', 'open',
    'message', v_message
  );
end;
$$;

create or replace function public.fn_rider_support_resolve_ticket(
  p_ticket_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_ticket public.tickets%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  select *
    into v_ticket
    from public.tickets
   where id = p_ticket_id
   for update;

  if not found
     or v_ticket.user_type <> 'rider'
     or v_ticket.user_id <> v_user_id::text then
    raise exception using errcode = '42501', message = 'ticket_not_accessible';
  end if;

  update public.tickets
     set status = 'resolved',
         resolved_at = v_now,
         resolved_by = v_user_id::text,
         resolution_summary = 'Resolved by rider.',
         resolution_outcome = 'user_confirmed_resolved',
         updated_at = v_now
   where id = p_ticket_id;

  return jsonb_build_object(
    'ok', true,
    'ticket_id', p_ticket_id,
    'status', 'resolved'
  );
end;
$$;

revoke all on function public.fn_rider_support_create_ticket(text, text) from public, anon;
revoke all on function public.fn_rider_support_append_message(uuid, text) from public, anon;
revoke all on function public.fn_rider_support_resolve_ticket(uuid) from public, anon;

grant execute on function public.fn_rider_support_create_ticket(text, text) to authenticated;
grant execute on function public.fn_rider_support_append_message(uuid, text) to authenticated;
grant execute on function public.fn_rider_support_resolve_ticket(uuid) to authenticated;
