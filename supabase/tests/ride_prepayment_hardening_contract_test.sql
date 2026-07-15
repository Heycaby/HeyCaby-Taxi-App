begin;

do $verify$
declare
  v_definition text;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_payments'
      and column_name = 'destination_organization_id'
  ) then
    raise exception 'immutable payment route destination is missing';
  end if;

  if not exists (
    select 1 from pg_index
    where indrelid = 'public.ride_payment_routes'::regclass
      and indisunique
      and pg_get_indexdef(indexrelid) ilike '%(ride_payment_id)%'
  ) then
    raise exception 'payment routing does not enforce one route per payment';
  end if;

  if not exists (
    select 1 from information_schema.triggers
    where event_object_schema = 'public'
      and event_object_table = 'ride_request_invites'
      and trigger_name = 'trg_ride_prepayment_invite_eligibility'
  ) or not exists (
    select 1 from information_schema.triggers
    where event_object_schema = 'public'
      and event_object_table = 'ride_requests'
      and trigger_name = 'trg_ride_prepayment_assignment_guard'
  ) then
    raise exception 'required-prepayment Driver eligibility is not guarded';
  end if;

  if has_function_privilege(
       'authenticated',
       'private.fn_ride_prepayment_driver_ready(uuid,uuid)',
       'execute'
     ) or has_function_privilege(
       'anon',
       'private.fn_ride_prepayment_driver_ready(uuid,uuid)',
       'execute'
     ) then
    raise exception 'private Driver prepayment readiness is client callable';
  end if;

  if has_function_privilege(
       'anon', 'public.fn_admin_ride_payment_config()', 'execute'
     ) or has_function_privilege(
       'anon',
       'public.fn_admin_update_ride_payment_config(integer,integer,integer)',
       'execute'
     ) then
    raise exception 'anonymous users can access Admin payment configuration';
  end if;

  select pg_get_functiondef(
    'public.fn_admin_update_ride_payment_config(integer,integer,integer)'::regprocedure
  ) into v_definition;
  if v_definition not ilike '%public.admin_users%'
     or v_definition not ilike '%ride_payment_config_audit%'
     or v_definition not ilike '%platform_fee_bps%'
  then
    raise exception 'Admin payment command lacks role, audit, or commission contract';
  end if;
end;
$verify$;

select 'ride_prepayment_hardening_contract_passed' as result;
rollback;
