-- Harden the dark-launched ride-prepayment branch without changing any
-- released ride behavior while the global and per-mode flags remain false.

alter table public.ride_payments
  add column if not exists destination_organization_id text;

comment on column public.ride_payments.destination_organization_id is
  'Immutable Mollie organization destination captured when checkout is created. Routing never follows a later account reconnect.';

create unique index if not exists ride_payment_routes_one_per_payment
  on public.ride_payment_routes (ride_payment_id);

-- One backend decision is shared by dispatch invitation and final acceptance.
-- Instant prepay remains optional and therefore never filters dispatch.
create or replace function private.fn_ride_prepayment_driver_ready(
  p_ride_id uuid,
  p_driver_id uuid
)
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_mode text;
  v_flags jsonb;
  v_required boolean := false;
begin
  select rr.booking_mode::text
  into v_mode
  from public.ride_requests rr
  where rr.id = p_ride_id;

  if v_mode not in ('scheduled', 'terug') then
    return true;
  end if;

  begin
    select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
    into v_flags
    from public.app_config ac
    where ac.key = 'feature_flags';
  exception when others then
    -- A malformed rollout contract must not send a required-prepay ride to an
    -- unverified destination.
    return false;
  end;

  v_required := coalesce(
    v_flags -> 'ride_prepaid_payments_enabled' = 'true'::jsonb,
    false
  ) and case v_mode
    when 'scheduled' then coalesce(
      v_flags -> 'ride_prepaid_scheduled_enabled' = 'true'::jsonb,
      false
    )
    when 'terug' then coalesce(
      v_flags -> 'ride_prepaid_taxi_terug_enabled' = 'true'::jsonb,
      false
    )
    else false
  end;

  if not v_required then
    return true;
  end if;

  return exists (
    select 1
    from public.driver_mollie_connections dmc
    where dmc.driver_id = p_driver_id
      and dmc.status = 'verified'
      and dmc.can_receive_prepaid_rides = true
      and nullif(btrim(dmc.organization_id), '') is not null
  );
end;
$$;

revoke all on function private.fn_ride_prepayment_driver_ready(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.fn_ride_prepayment_driver_ready(uuid, uuid)
  to service_role;

create or replace function private.trg_filter_prepayment_invite_driver()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.fn_ride_prepayment_driver_ready(
    new.ride_request_id,
    new.driver_id
  ) then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function private.trg_filter_prepayment_invite_driver()
  from public, anon, authenticated;

drop trigger if exists trg_ride_prepayment_invite_eligibility
  on public.ride_request_invites;
create trigger trg_ride_prepayment_invite_eligibility
before insert on public.ride_request_invites
for each row execute function private.trg_filter_prepayment_invite_driver();

create or replace function private.trg_guard_prepayment_ride_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.driver_id is not null
     and new.status in ('assigned', 'accepted', 'driver_found')
     and (
       old.driver_id is distinct from new.driver_id
       or old.status is distinct from new.status
     )
     and not private.fn_ride_prepayment_driver_ready(new.id, new.driver_id)
  then
    raise exception using
      errcode = 'P0001',
      message = 'driver_not_prepay_ready',
      hint = 'Required-prepayment rides may only be assigned to a verified Mollie Connect Driver.';
  end if;
  return new;
end;
$$;

revoke all on function private.trg_guard_prepayment_ride_assignment()
  from public, anon, authenticated;

drop trigger if exists trg_ride_prepayment_assignment_guard
  on public.ride_requests;
create trigger trg_ride_prepayment_assignment_guard
before update of status, driver_id on public.ride_requests
for each row execute function private.trg_guard_prepayment_ride_assignment();

-- Completion creates a durable routing work item. The Edge Function performs
-- the external Mollie call; this trigger never performs network I/O.
create or replace function private.trg_mark_completed_prepayment_for_routing()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  with moved as (
    update public.ride_payments rp
    set state = case
          when rp.driver_route_cents = 0 then 'routed'
          else 'routing_pending'
        end,
        routed_at = case
          when rp.driver_route_cents = 0 then timezone('utc', now())
          else rp.routed_at
        end,
        updated_at = timezone('utc', now())
    where rp.ride_id = new.id
      and rp.state = 'paid'
    returning rp.*
  )
  insert into public.ride_payment_events (
    ride_payment_id,
    ride_id,
    event_type,
    provider_event_key,
    from_state,
    to_state,
    source,
    correlation_id,
    payload
  )
  select
    m.id,
    m.ride_id,
    'payment_routing_requested',
    'completion:' || m.ride_id::text,
    'paid',
    m.state,
    'ride_completion',
    m.correlation_id,
    jsonb_build_object(
      'driver_route_cents', m.driver_route_cents,
      'platform_fee_cents', m.platform_fee_cents,
      'destination_organization_id', m.destination_organization_id
    )
  from moved m
  on conflict (source, provider_event_key) do nothing;

  return new;
end;
$$;

revoke all on function private.trg_mark_completed_prepayment_for_routing()
  from public, anon, authenticated;

drop trigger if exists trg_completed_ride_payment_routing
  on public.ride_requests;
create trigger trg_completed_ride_payment_routing
after update of status on public.ride_requests
for each row
when (new.status = 'completed' and old.status is distinct from new.status)
execute function private.trg_mark_completed_prepayment_for_routing();

-- Admin-facing settings contract. External Admin tools consume these RPCs;
-- direct app_config writes are not the payment-domain command boundary.
create table if not exists public.ride_payment_config_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null,
  old_config jsonb not null,
  new_config jsonb not null,
  correlation_id uuid not null default gen_random_uuid(),
  occurred_at timestamptz not null default timezone('utc', now())
);

alter table public.ride_payment_config_audit enable row level security;
revoke all on public.ride_payment_config_audit from anon, authenticated;

create or replace function public.fn_admin_ride_payment_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_config jsonb;
begin
  if not exists (
    select 1 from public.admin_users au
    where au.user_id = (select auth.uid())
  ) then
    return jsonb_build_object('ok', false, 'error', 'admin_required');
  end if;

  select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
  into v_config
  from public.app_config ac
  where ac.key = 'ride_prepaid_payment_config';

  return jsonb_build_object('ok', true, 'config', coalesce(v_config, '{}'::jsonb));
exception when others then
  return jsonb_build_object('ok', false, 'error', 'payment_config_invalid');
end;
$$;

create or replace function public.fn_admin_update_ride_payment_config(
  p_platform_fee_bps integer default null,
  p_free_cancellation_minutes integer default null,
  p_late_cancellation_fee_bps integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_old jsonb;
  v_new jsonb;
  v_platform_fee_bps integer;
  v_free_cancellation_minutes integer;
  v_late_cancellation_fee_bps integer;
begin
  if not exists (
    select 1 from public.admin_users au where au.user_id = v_actor
  ) then
    return jsonb_build_object('ok', false, 'error', 'admin_required');
  end if;

  select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
  into v_old
  from public.app_config ac
  where ac.key = 'ride_prepaid_payment_config'
  for update;

  if v_old is null then
    return jsonb_build_object('ok', false, 'error', 'payment_config_missing');
  end if;

  v_platform_fee_bps := coalesce(
    p_platform_fee_bps,
    (v_old ->> 'platform_fee_bps')::integer,
    0
  );
  v_free_cancellation_minutes := coalesce(
    p_free_cancellation_minutes,
    (v_old ->> 'free_cancellation_minutes')::integer,
    0
  );
  v_late_cancellation_fee_bps := coalesce(
    p_late_cancellation_fee_bps,
    (v_old ->> 'late_cancellation_fee_bps')::integer,
    0
  );

  if v_platform_fee_bps not between 0 and 10000
     or v_free_cancellation_minutes not between 0 and 10080
     or v_late_cancellation_fee_bps not between 0 and 10000
  then
    return jsonb_build_object('ok', false, 'error', 'payment_config_out_of_range');
  end if;

  v_new := v_old || jsonb_build_object(
    'platform_fee_bps', v_platform_fee_bps,
    'free_cancellation_minutes', v_free_cancellation_minutes,
    'late_cancellation_fee_bps', v_late_cancellation_fee_bps
  );

  update public.app_config
  set value = v_new::text
  where key = 'ride_prepaid_payment_config';

  insert into public.ride_payment_config_audit(actor_id, old_config, new_config)
  values (v_actor, v_old, v_new);

  return jsonb_build_object('ok', true, 'config', v_new);
exception when others then
  return jsonb_build_object('ok', false, 'error', 'payment_config_invalid');
end;
$$;

revoke all on function public.fn_admin_ride_payment_config()
  from public, anon;
grant execute on function public.fn_admin_ride_payment_config()
  to authenticated, service_role;

revoke all on function public.fn_admin_update_ride_payment_config(
  integer, integer, integer
) from public, anon;
grant execute on function public.fn_admin_update_ride_payment_config(
  integer, integer, integer
) to authenticated, service_role;

comment on function public.fn_admin_update_ride_payment_config(
  integer, integer, integer
) is
  'Canonical Admin command for configurable ride-prepayment commission and cancellation settings; every mutation is audited.';
