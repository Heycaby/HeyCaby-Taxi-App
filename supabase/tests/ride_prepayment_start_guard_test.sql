begin;

do $verify$
declare
  v_driver constant uuid := '10000000-0000-0000-0000-000000000001';
  v_ride constant uuid := '20000000-0000-0000-0000-000000000001';
  v_payment constant uuid := '30000000-0000-0000-0000-000000000001';
  v_result jsonb;
  v_definition text;
begin
  insert into public.app_config(key, value) values (
    'feature_flags',
    '{"ride_prepaid_payments_enabled":false,"ride_prepaid_scheduled_enabled":false,"ride_prepaid_taxi_terug_enabled":false,"ride_prepaid_instant_optional_enabled":false}'
  );
  insert into public.app_config(key, value) values (
    'ride_prepaid_rollout',
    '{"allowed_rider_cohort_percentage":100,"allowed_driver_ids":[]}'
  );
  insert into public.mollie_marketplace_health(
    singleton, routing_capability_confirmed
  ) values (true, true)
  on conflict (singleton) do update
    set routing_capability_confirmed = excluded.routing_capability_confirmed;
  insert into public.ride_requests (
    id, driver_id, status, booking_mode, payment_status, driver_arrived_at
  ) values (
    v_ride, v_driver, 'driver_arrived', 'scheduled', 'pending', now()
  );

  -- Flags off: the released scheduled ride path remains unchanged.
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'ok' <> 'true' then
    raise exception 'flags-off scheduled ride was blocked: %', v_result;
  end if;

  update public.ride_requests
  set status = 'driver_arrived', started_at = null, payment_status = 'pending'
  where id = v_ride;
  update public.app_config set value =
    '{"ride_prepaid_payments_enabled":true,"ride_prepaid_scheduled_enabled":true,"ride_prepaid_taxi_terug_enabled":true,"ride_prepaid_instant_optional_enabled":true,"mollie_marketplace_routing_enabled":true}'
  where key = 'feature_flags';

  -- Required scheduled payment missing: fail closed.
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'error' <> 'ride_prepayment_required' then
    raise exception 'unpaid scheduled ride was not blocked: %', v_result;
  end if;

  insert into public.ride_payments (
    id, ride_id, state, paid_at, refunded_cents
  ) values (v_payment, v_ride, 'open', null, 0);
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'error' <> 'ride_prepayment_required' then
    raise exception 'open scheduled payment was not blocked: %', v_result;
  end if;

  update public.ride_payments
  set state = 'paid', paid_at = now(), refunded_cents = 0
  where id = v_payment;
  update public.ride_requests set payment_status = 'confirmed' where id = v_ride;
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'ok' <> 'true' then
    raise exception 'webhook-confirmed scheduled payment was blocked: %', v_result;
  end if;

  -- A pre-start refund invalidates the paid state for boarding.
  update public.ride_requests
  set status = 'driver_arrived', started_at = null
  where id = v_ride;
  update public.ride_payments set refunded_cents = 100 where id = v_payment;
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'error' <> 'ride_prepayment_required' then
    raise exception 'refunded scheduled payment was not blocked: %', v_result;
  end if;

  -- Taxi Terug is required under its mode flag.
  delete from public.ride_payments where ride_id = v_ride;
  update public.ride_requests
  set booking_mode = 'terug', payment_status = 'pending'
  where id = v_ride;
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'error' <> 'ride_prepayment_required' then
    raise exception 'unpaid Taxi Terug ride was not blocked: %', v_result;
  end if;

  -- Optional instant and unsupported marketplace modes are never start-gated.
  update public.ride_requests
  set booking_mode = 'instant', status = 'driver_arrived'
  where id = v_ride;
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'ok' <> 'true' then
    raise exception 'instant ride was incorrectly blocked: %', v_result;
  end if;

  update public.ride_requests
  set booking_mode = 'marketplace', status = 'driver_arrived', started_at = null
  where id = v_ride;
  v_result := public.fn_driver_ride_start(v_ride)::jsonb;
  if v_result ->> 'ok' <> 'true' then
    raise exception 'marketplace ride was incorrectly blocked: %', v_result;
  end if;

  select pg_get_functiondef('public.fn_driver_ride_start(uuid)'::regprocedure)
  into v_definition;
  if position('private.fn_ride_prepayment_start_decision' in v_definition) = 0
     or position('private.fn_ride_prepayment_start_decision' in v_definition)
        > position('set status = ''in_progress''' in lower(v_definition)) then
    raise exception 'prepayment guard is not before the in_progress update';
  end if;

  if has_function_privilege(
       'anon',
       'private.fn_ride_prepayment_start_decision(uuid,text,text)',
       'execute'
     ) or has_function_privilege(
       'authenticated',
       'private.fn_ride_prepayment_start_decision(uuid,text,text)',
       'execute'
     ) then
    raise exception 'internal prepayment decision helper is client-callable';
  end if;

  if has_function_privilege(
       'anon', 'public.fn_driver_ride_start(uuid)', 'execute'
     ) or not has_function_privilege(
       'authenticated', 'public.fn_driver_ride_start(uuid)', 'execute'
     ) then
    raise exception 'canonical ride-start grants changed unexpectedly';
  end if;
end;
$verify$;

select 'ride_prepayment_start_guard_passed' as result;
rollback;
