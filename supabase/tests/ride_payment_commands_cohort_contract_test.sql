begin;

do $verify$
declare
  v_flags jsonb;
  v_rollout jsonb;
  v_definition text;
begin
  select value::jsonb into v_flags from public.app_config where key = 'feature_flags';
  select value::jsonb into v_rollout from public.app_config where key = 'ride_prepaid_rollout';
  if coalesce((v_flags ->> 'mollie_marketplace_routing_enabled')::boolean, true)
     or coalesce((v_rollout ->> 'allowed_rider_cohort_percentage')::integer, -1) <> 0 then
    raise exception 'Mollie rollout did not deploy fail-closed';
  end if;
  if (select routing_capability_confirmed from public.mollie_marketplace_health where singleton) then
    raise exception 'Marketplace capability was marked confirmed without evidence';
  end if;
  if has_function_privilege(
       'authenticated', 'public.fn_ride_prepayment_checkout_decision(uuid,uuid)', 'execute'
     ) or has_function_privilege(
       'authenticated', 'public.fn_scan_ride_payment_alerts()', 'execute'
     ) then
    raise exception 'internal payment control is client callable';
  end if;
  if has_function_privilege(
       'anon', 'public.fn_admin_ride_payment_timeline(uuid)', 'execute'
     ) or has_function_privilege(
       'anon', 'public.fn_admin_update_ride_payment_policy(integer,integer,integer,integer)', 'execute'
     ) then
    raise exception 'anonymous users can access Admin payment contracts';
  end if;
  if not exists (
    select 1 from pg_index
    where indrelid = 'public.ride_payment_refunds'::regclass
      and indisunique and pg_get_indexdef(indexrelid) ilike '%command_key%'
  ) then raise exception 'refund command idempotency index is missing'; end if;
  select pg_get_functiondef(
    'private.fn_ride_prepayment_rollout_decision(uuid,uuid)'::regprocedure
  ) into v_definition;
  if v_definition not ilike '%mollie_marketplace_routing_enabled%'
     or v_definition not ilike '%allowed_rider_cohort_percentage%'
     or v_definition not ilike '%allowed_driver_ids%' then
    raise exception 'canonical rollout decision is incomplete';
  end if;
end;
$verify$;

select 'ride_payment_commands_cohort_contract_passed' as result;
rollback;
