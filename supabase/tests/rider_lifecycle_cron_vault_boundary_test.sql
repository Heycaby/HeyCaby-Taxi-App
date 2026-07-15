begin;

do $test$
declare
  v_command text;
begin
  if to_regprocedure(
    'private.fn_invoke_rider_lifecycle_dispatch(integer)'
  ) is null then
    raise exception 'missing private Rider lifecycle cron boundary';
  end if;

  if has_function_privilege(
    'anon',
    'private.fn_invoke_rider_lifecycle_dispatch(integer)',
    'EXECUTE'
  ) then
    raise exception 'anon must not execute Rider lifecycle cron boundary';
  end if;

  if has_function_privilege(
    'authenticated',
    'private.fn_invoke_rider_lifecycle_dispatch(integer)',
    'EXECUTE'
  ) then
    raise exception 'authenticated must not execute Rider lifecycle cron boundary';
  end if;

  if not has_function_privilege(
    'service_role',
    'private.fn_invoke_rider_lifecycle_dispatch(integer)',
    'EXECUTE'
  ) then
    raise exception 'service_role must execute Rider lifecycle cron boundary';
  end if;

  select j.command
  into v_command
  from cron.job j
  where j.jobname = 'rider-lifecycle-dispatch-every-20m';

  if v_command is distinct from
     'SELECT private.fn_invoke_rider_lifecycle_dispatch(50);' then
    raise exception 'cron job does not use the private Vault boundary';
  end if;

  if v_command ilike '%x-webhook-secret%'
     or v_command ilike '%supabase.co/functions/%' then
    raise exception 'cron command still embeds transport configuration';
  end if;
end;
$test$;

rollback;
