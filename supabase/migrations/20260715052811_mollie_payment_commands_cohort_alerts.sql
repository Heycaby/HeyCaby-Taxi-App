-- Four-workstream containment for Mollie marketplace payments.
-- Existing ride_prepaid_* flags remain canonical; duplicate alias flags are
-- intentionally not introduced. All rollout controls default fail-closed.

update public.app_config
set value = (
  coalesce(nullif(value, '')::jsonb, '{}'::jsonb)
  || jsonb_build_object('mollie_marketplace_routing_enabled', false)
)::text
where key = 'feature_flags';

insert into public.app_config(key, value)
values (
  'ride_prepaid_rollout',
  jsonb_build_object(
    'allowed_rider_cohort_percentage', 0,
    'allowed_driver_ids', '[]'::jsonb
  )::text
)
on conflict (key) do nothing;

update public.app_config
set value = (
  coalesce(nullif(value, '')::jsonb, '{}'::jsonb)
  || jsonb_build_object(
    'no_show_fee_bps', 0,
    'unrouted_alert_hours', 24,
    'refund_pending_alert_minutes', 15,
    'minimum_refund_balance_cents', 0
  )
)::text
where key = 'ride_prepaid_payment_config';

alter table public.ride_payment_refunds
  add column if not exists command_key text,
  add column if not exists admin_reason text,
  add column if not exists routing_reversal_cents integer not null default 0,
  add column if not exists policy_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists provider_failure_code text,
  add column if not exists completed_at timestamptz;

alter table public.ride_payment_refunds
  drop constraint if exists ride_payment_refunds_state_check;
alter table public.ride_payment_refunds
  add constraint ride_payment_refunds_state_check
  check (state in (
    'creating', 'queued', 'pending', 'processing', 'refunded', 'failed', 'canceled'
  ));
alter table public.ride_payment_refunds
  drop constraint if exists ride_payment_refunds_routing_reversal_check;
alter table public.ride_payment_refunds
  add constraint ride_payment_refunds_routing_reversal_check
  check (routing_reversal_cents >= 0 and routing_reversal_cents <= amount_cents);

create unique index if not exists ride_payment_refunds_command_key_unique
  on public.ride_payment_refunds(ride_payment_id, command_key)
  where command_key is not null;

create table if not exists public.ride_payment_webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  provider_payment_id text not null,
  ride_payment_id uuid references public.ride_payments(id) on delete restrict,
  ride_id uuid references public.ride_requests(id) on delete restrict,
  outcome text not null default 'received'
    check (outcome in ('received', 'processed', 'rejected', 'failed', 'duplicate')),
  error_code text,
  correlation_id uuid,
  received_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz
);

create index if not exists ride_payment_webhooks_payment_time_idx
  on public.ride_payment_webhook_deliveries(provider_payment_id, received_at desc);

create table if not exists public.ride_payment_chargebacks (
  id uuid primary key default gen_random_uuid(),
  ride_payment_id uuid not null references public.ride_payments(id) on delete restrict,
  provider_chargeback_id text not null unique,
  amount_cents integer not null check (amount_cents > 0),
  state text not null,
  provider_snapshot jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.mollie_marketplace_health (
  singleton boolean primary key default true check (singleton),
  routing_capability_confirmed boolean not null default false,
  capability_confirmed_at timestamptz,
  capability_confirmed_by uuid,
  available_balance_cents integer,
  balance_currency text not null default 'EUR',
  last_provider_check_at timestamptz,
  provider_snapshot jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);
insert into public.mollie_marketplace_health(singleton)
values (true) on conflict (singleton) do nothing;

create table if not exists public.ride_payment_operational_alerts (
  id uuid primary key default gen_random_uuid(),
  dedupe_key text not null unique,
  alert_type text not null,
  severity text not null check (severity in ('warning', 'critical')),
  ride_id uuid references public.ride_requests(id) on delete set null,
  ride_payment_id uuid references public.ride_payments(id) on delete set null,
  driver_id uuid references public.drivers(id) on delete set null,
  correlation_id uuid,
  details jsonb not null default '{}'::jsonb,
  first_detected_at timestamptz not null default timezone('utc', now()),
  last_detected_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz
);

alter table public.ride_payment_webhook_deliveries enable row level security;
alter table public.ride_payment_chargebacks enable row level security;
alter table public.mollie_marketplace_health enable row level security;
alter table public.ride_payment_operational_alerts enable row level security;
revoke all on public.ride_payment_webhook_deliveries from anon, authenticated;
revoke all on public.ride_payment_chargebacks from anon, authenticated;
revoke all on public.mollie_marketplace_health from anon, authenticated;
revoke all on public.ride_payment_operational_alerts from anon, authenticated;

create or replace function private.fn_ride_prepayment_rollout_decision(
  p_ride_id uuid,
  p_driver_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ride record;
  v_flags jsonb := '{}'::jsonb;
  v_rollout jsonb := '{}'::jsonb;
  v_mode_flag text;
  v_percentage integer := 0;
  v_bucket integer := 100;
  v_allowed_drivers jsonb := '[]'::jsonb;
begin
  select rr.id, rr.booking_mode::text as booking_mode,
         rr.rider_identity_id, rr.rider_token
  into v_ride
  from public.ride_requests rr
  where rr.id = p_ride_id;
  if v_ride.id is null then
    return jsonb_build_object('enabled', false, 'reason', 'ride_not_found');
  end if;

  begin
    select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
      into v_flags from public.app_config ac where ac.key = 'feature_flags';
    select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
      into v_rollout from public.app_config ac where ac.key = 'ride_prepaid_rollout';
  exception when others then
    return jsonb_build_object('enabled', false, 'reason', 'payment_config_invalid');
  end;

  if coalesce(v_flags -> 'ride_prepaid_payments_enabled' = 'true'::jsonb, false)
     is not true then
    return jsonb_build_object('enabled', false, 'reason', 'global_flag_disabled');
  end if;
  if coalesce(v_flags -> 'mollie_marketplace_routing_enabled' = 'true'::jsonb, false)
     is not true then
    return jsonb_build_object('enabled', false, 'reason', 'marketplace_routing_disabled');
  end if;
  if not exists (
    select 1 from public.mollie_marketplace_health h
    where h.singleton and h.routing_capability_confirmed
  ) then
    return jsonb_build_object('enabled', false, 'reason', 'marketplace_capability_unconfirmed');
  end if;

  v_mode_flag := case v_ride.booking_mode
    when 'scheduled' then 'ride_prepaid_scheduled_enabled'
    when 'terug' then 'ride_prepaid_taxi_terug_enabled'
    when 'instant' then 'ride_prepaid_instant_optional_enabled'
    else null
  end;
  if v_mode_flag is null
     or coalesce(v_flags -> v_mode_flag = 'true'::jsonb, false) is not true then
    return jsonb_build_object('enabled', false, 'reason', 'mode_flag_disabled');
  end if;

  begin
    v_percentage := coalesce((v_rollout ->> 'allowed_rider_cohort_percentage')::integer, 0);
  exception when others then
    return jsonb_build_object('enabled', false, 'reason', 'payment_config_invalid');
  end;
  if v_percentage not between 0 and 100 then
    return jsonb_build_object('enabled', false, 'reason', 'payment_config_invalid');
  end if;
  v_bucket := mod((('x' || substr(md5(coalesce(
    v_ride.rider_identity_id::text,
    v_ride.rider_token,
    v_ride.id::text
  )), 1, 8))::bit(32)::bigint), 100)::integer;
  if v_bucket >= v_percentage then
    return jsonb_build_object(
      'enabled', false, 'reason', 'rider_outside_cohort', 'cohort_bucket', v_bucket
    );
  end if;

  v_allowed_drivers := coalesce(v_rollout -> 'allowed_driver_ids', '[]'::jsonb);
  if jsonb_typeof(v_allowed_drivers) <> 'array' then
    return jsonb_build_object('enabled', false, 'reason', 'payment_config_invalid');
  end if;
  if jsonb_array_length(v_allowed_drivers) > 0
     and not (v_allowed_drivers ? p_driver_id::text) then
    return jsonb_build_object('enabled', false, 'reason', 'driver_outside_cohort');
  end if;

  return jsonb_build_object(
    'enabled', true, 'reason', 'eligible', 'booking_mode', v_ride.booking_mode,
    'cohort_bucket', v_bucket
  );
end;
$$;

revoke all on function private.fn_ride_prepayment_rollout_decision(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.fn_ride_prepayment_rollout_decision(uuid, uuid)
  to service_role;

create or replace function public.fn_ride_prepayment_checkout_decision(
  p_ride_id uuid,
  p_driver_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_decision jsonb;
begin
  v_decision := private.fn_ride_prepayment_rollout_decision(p_ride_id, p_driver_id);
  if coalesce((v_decision ->> 'enabled')::boolean, false) is not true then
    return v_decision;
  end if;
  if not exists (
    select 1 from public.driver_mollie_connections dmc
    where dmc.driver_id = p_driver_id
      and dmc.status = 'verified'
      and dmc.can_receive_prepaid_rides
      and nullif(btrim(dmc.organization_id), '') is not null
  ) then
    return v_decision || jsonb_build_object(
      'enabled', false, 'reason', 'driver_not_prepay_ready'
    );
  end if;
  return v_decision;
end;
$$;
revoke all on function public.fn_ride_prepayment_checkout_decision(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.fn_ride_prepayment_checkout_decision(uuid, uuid)
  to service_role;

-- Existing invitation and start boundaries now consume the same rollout
-- decision. A disabled capability means the released pay-driver flow remains.
create or replace function private.fn_ride_prepayment_driver_ready(
  p_ride_id uuid,
  p_driver_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_decision jsonb;
begin
  v_decision := private.fn_ride_prepayment_rollout_decision(p_ride_id, p_driver_id);
  if coalesce((v_decision ->> 'enabled')::boolean, false) is not true then
    return true;
  end if;
  return exists (
    select 1 from public.driver_mollie_connections dmc
    where dmc.driver_id = p_driver_id and dmc.status = 'verified'
      and dmc.can_receive_prepaid_rides
      and nullif(btrim(dmc.organization_id), '') is not null
  );
end;
$$;
revoke all on function private.fn_ride_prepayment_driver_ready(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.fn_ride_prepayment_driver_ready(uuid, uuid)
  to service_role;

create or replace function private.fn_ride_prepayment_start_decision(
  p_ride_id uuid,
  p_booking_mode text,
  p_ride_payment_status text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid;
  v_rollout jsonb;
  v_payment public.ride_payments%rowtype;
begin
  select rr.driver_id into v_driver_id
  from public.ride_requests rr where rr.id = p_ride_id;
  v_rollout := private.fn_ride_prepayment_rollout_decision(p_ride_id, v_driver_id);
  if coalesce((v_rollout ->> 'enabled')::boolean, false) is not true then
    return jsonb_build_object(
      'allowed', true, 'required', false, 'reason', v_rollout ->> 'reason'
    );
  end if;

  select rp.* into v_payment from public.ride_payments rp
  where rp.ride_id = p_ride_id order by rp.created_at desc limit 1;
  if v_payment.id is null or v_payment.state <> 'paid'
     or v_payment.paid_at is null or coalesce(v_payment.refunded_cents, 0) <> 0
     or coalesce(p_ride_payment_status, '') not in ('confirmed', 'paid') then
    return jsonb_build_object(
      'allowed', false, 'required', true, 'reason', 'ride_prepayment_required',
      'payment_id', v_payment.id,
      'payment_state', coalesce(v_payment.state, 'missing'),
      'ride_payment_status', p_ride_payment_status,
      'refunded_cents', coalesce(v_payment.refunded_cents, 0)
    );
  end if;
  return jsonb_build_object(
    'allowed', true, 'required', true, 'reason', 'paid',
    'payment_id', v_payment.id, 'payment_state', v_payment.state
  );
end;
$$;
revoke all on function private.fn_ride_prepayment_start_decision(uuid, text, text)
  from public, anon, authenticated;
grant execute on function private.fn_ride_prepayment_start_decision(uuid, text, text)
  to service_role;

create or replace function public.fn_admin_ride_payment_timeline(p_ride_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_payment public.ride_payments%rowtype;
begin
  if not exists (
    select 1 from public.admin_users au
    where au.user_id = v_actor and au.is_active
      and au.role in ('admin', 'super_admin')
  ) then return jsonb_build_object('ok', false, 'error', 'admin_required'); end if;
  select * into v_payment from public.ride_payments
  where ride_id = p_ride_id order by created_at desc limit 1;
  if v_payment.id is null then
    return jsonb_build_object('ok', true, 'ride_id', p_ride_id, 'payment', null, 'timeline', '[]'::jsonb);
  end if;
  return jsonb_build_object(
    'ok', true,
    'ride_id', p_ride_id,
    'payment', jsonb_build_object(
      'id', v_payment.id, 'state', v_payment.state,
      'amount_cents', v_payment.amount_cents,
      'driver_share_cents', v_payment.driver_route_cents,
      'platform_fee_cents', v_payment.platform_fee_cents,
      'refunded_cents', v_payment.refunded_cents,
      'currency', v_payment.currency, 'correlation_id', v_payment.correlation_id
    ),
    'timeline', coalesce((
      select jsonb_agg(e order by e ->> 'occurred_at') from (
        select jsonb_build_object(
          'type', pe.event_type, 'state', pe.to_state,
          'occurred_at', pe.occurred_at, 'source', pe.source,
          'payload', pe.payload
        ) e from public.ride_payment_events pe where pe.ride_payment_id = v_payment.id
        union all
        select jsonb_build_object(
          'type', 'refund.' || pr.state, 'state', pr.state,
          'occurred_at', pr.updated_at, 'source', 'mollie_refund',
          'payload', jsonb_build_object('amount_cents', pr.amount_cents, 'reason', pr.reason_code)
        ) from public.ride_payment_refunds pr where pr.ride_payment_id = v_payment.id
        union all
        select jsonb_build_object(
          'type', 'route.' || rt.state, 'state', rt.state,
          'occurred_at', rt.updated_at, 'source', 'mollie_route',
          'payload', jsonb_build_object('amount_cents', rt.amount_cents, 'organization_id', rt.organization_id)
        ) from public.ride_payment_routes rt where rt.ride_payment_id = v_payment.id
      ) q
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.fn_admin_ride_payment_timeline(uuid) from public, anon;
grant execute on function public.fn_admin_ride_payment_timeline(uuid)
  to authenticated, service_role;

create or replace function public.fn_admin_update_ride_payment_policy(
  p_platform_fee_bps integer default null,
  p_free_cancellation_minutes integer default null,
  p_late_cancellation_fee_bps integer default null,
  p_no_show_fee_bps integer default null
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
  v_platform integer;
  v_window integer;
  v_late integer;
  v_no_show integer;
begin
  if not exists (
    select 1 from public.admin_users au
    where au.user_id = v_actor and au.is_active
      and au.role in ('admin', 'super_admin')
  ) then return jsonb_build_object('ok', false, 'error', 'admin_required'); end if;

  select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
    into v_old from public.app_config ac
    where ac.key = 'ride_prepaid_payment_config' for update;
  if v_old is null then
    return jsonb_build_object('ok', false, 'error', 'payment_config_missing');
  end if;
  v_platform := coalesce(p_platform_fee_bps, (v_old ->> 'platform_fee_bps')::integer, 0);
  v_window := coalesce(p_free_cancellation_minutes, (v_old ->> 'free_cancellation_minutes')::integer, 0);
  v_late := coalesce(p_late_cancellation_fee_bps, (v_old ->> 'late_cancellation_fee_bps')::integer, 0);
  v_no_show := coalesce(p_no_show_fee_bps, (v_old ->> 'no_show_fee_bps')::integer, 0);
  if v_platform not between 0 and 10000
     or v_window not between 0 and 10080
     or v_late not between 0 and 10000
     or v_no_show not between 0 and 10000 then
    return jsonb_build_object('ok', false, 'error', 'payment_config_out_of_range');
  end if;
  v_new := v_old || jsonb_build_object(
    'platform_fee_bps', v_platform,
    'free_cancellation_minutes', v_window,
    'late_cancellation_fee_bps', v_late,
    'no_show_fee_bps', v_no_show
  );
  update public.app_config set value = v_new::text
    where key = 'ride_prepaid_payment_config';
  insert into public.ride_payment_config_audit(actor_id, old_config, new_config)
    values (v_actor, v_old, v_new);
  return jsonb_build_object('ok', true, 'config', v_new);
exception when others then
  return jsonb_build_object('ok', false, 'error', 'payment_config_invalid');
end;
$$;
revoke all on function public.fn_admin_update_ride_payment_policy(integer, integer, integer, integer)
  from public, anon;
grant execute on function public.fn_admin_update_ride_payment_policy(integer, integer, integer, integer)
  to authenticated, service_role;

create or replace function public.fn_admin_update_ride_payment_rollout(
  p_allowed_rider_cohort_percentage integer,
  p_allowed_driver_ids uuid[] default '{}'::uuid[]
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
begin
  if not exists (
    select 1 from public.admin_users au
    where au.user_id = v_actor and au.is_active
      and au.role in ('admin', 'super_admin')
  ) then return jsonb_build_object('ok', false, 'error', 'admin_required'); end if;
  if p_allowed_rider_cohort_percentage not between 0 and 100 then
    return jsonb_build_object('ok', false, 'error', 'cohort_percentage_out_of_range');
  end if;
  if exists (
    select 1 from unnest(coalesce(p_allowed_driver_ids, '{}'::uuid[])) requested(id)
    where not exists (select 1 from public.drivers d where d.id = requested.id)
  ) then return jsonb_build_object('ok', false, 'error', 'unknown_driver_id'); end if;
  select coalesce(nullif(ac.value, '')::jsonb, '{}'::jsonb)
    into v_old from public.app_config ac where ac.key = 'ride_prepaid_rollout' for update;
  v_new := jsonb_build_object(
    'allowed_rider_cohort_percentage', p_allowed_rider_cohort_percentage,
    'allowed_driver_ids', to_jsonb(coalesce(p_allowed_driver_ids, '{}'::uuid[]))
  );
  update public.app_config set value = v_new::text where key = 'ride_prepaid_rollout';
  insert into public.ride_payment_config_audit(actor_id, old_config, new_config)
    values (v_actor, coalesce(v_old, '{}'::jsonb), v_new);
  return jsonb_build_object('ok', true, 'rollout', v_new);
exception when others then
  return jsonb_build_object('ok', false, 'error', 'rollout_config_invalid');
end;
$$;
revoke all on function public.fn_admin_update_ride_payment_rollout(integer, uuid[])
  from public, anon;
grant execute on function public.fn_admin_update_ride_payment_rollout(integer, uuid[])
  to authenticated, service_role;

create or replace function public.fn_scan_ride_payment_alerts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_inserted integer := 0; v_count integer := 0;
begin
  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id, driver_id,
    correlation_id, details
  )
  select 'route:' || rp.id, 'payment_paid_not_routed', 'critical', rp.ride_id,
    rp.id, rp.driver_id, rp.correlation_id,
    jsonb_build_object('state', rp.state, 'updated_at', rp.updated_at)
  from public.ride_payments rp join public.ride_requests rr on rr.id = rp.ride_id
  where rr.status = 'completed' and rp.state in ('paid','routing_pending','routing_failed')
    and rp.updated_at < timezone('utc', now()) - interval '10 minutes'
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id,
    correlation_id, details
  )
  select 'webhook-failed:' || wd.id, 'mollie_webhook_failure', 'critical',
    wd.ride_id, wd.ride_payment_id, wd.correlation_id,
    jsonb_build_object('provider_payment_id', wd.provider_payment_id,
      'error_code', wd.error_code, 'received_at', wd.received_at)
  from public.ride_payment_webhook_deliveries wd
  where wd.outcome in ('failed', 'rejected')
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id, driver_id,
    correlation_id, details
  )
  select 'unrouted-deadline:' || rp.id, 'unrouted_payment_deadline_approaching',
    'warning', rp.ride_id, rp.id, rp.driver_id, rp.correlation_id,
    jsonb_build_object('paid_at', rp.paid_at, 'state', rp.state)
  from public.ride_payments rp
  where rp.state in ('paid', 'routing_pending', 'routing_failed')
    and rp.paid_at < timezone('utc', now()) - make_interval(hours => greatest(1,
      coalesce((select (nullif(ac.value, '')::jsonb ->> 'unrouted_alert_hours')::integer
        from public.app_config ac where ac.key = 'ride_prepaid_payment_config'), 24) - 1))
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id, driver_id,
    correlation_id, details
  )
  select 'refund:' || pr.id, 'refund_failed_or_stuck',
    case when pr.state = 'failed' then 'critical' else 'warning' end,
    rp.ride_id, rp.id, rp.driver_id, rp.correlation_id,
    jsonb_build_object('refund_id', pr.id, 'state', pr.state, 'amount_cents', pr.amount_cents)
  from public.ride_payment_refunds pr join public.ride_payments rp on rp.id = pr.ride_payment_id
  where pr.state = 'failed' or (
    pr.state in ('creating','queued','pending','processing')
    and pr.updated_at < timezone('utc', now()) - interval '15 minutes'
  )
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id, driver_id,
    correlation_id, details
  )
  select 'driver:' || rp.id, 'prepaid_driver_not_connected', 'critical',
    rp.ride_id, rp.id, rp.driver_id, rp.correlation_id,
    jsonb_build_object('payment_state', rp.state)
  from public.ride_payments rp
  left join public.driver_mollie_connections dmc on dmc.driver_id = rp.driver_id
  where coalesce(dmc.status, '') <> 'verified'
     or coalesce(dmc.can_receive_prepaid_rides, false) is not true
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id, correlation_id, details
  )
  select 'webhook-repeat:' || wd.provider_payment_id, 'webhook_repeated_delivery',
    'warning', (array_agg(wd.ride_id))[1], (array_agg(wd.ride_payment_id))[1],
    (array_agg(wd.correlation_id))[1],
    jsonb_build_object('deliveries_15m', count(*))
  from public.ride_payment_webhook_deliveries wd
  where wd.received_at > timezone('utc', now()) - interval '15 minutes'
  group by wd.provider_payment_id having count(*) >= 4
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, ride_id, ride_payment_id, driver_id,
    correlation_id, details
  )
  select 'chargeback:' || cb.provider_chargeback_id, 'chargeback_received', 'critical',
    rp.ride_id, rp.id, rp.driver_id, rp.correlation_id,
    jsonb_build_object('chargeback_id', cb.provider_chargeback_id, 'amount_cents', cb.amount_cents)
  from public.ride_payment_chargebacks cb join public.ride_payments rp on rp.id = cb.ride_payment_id
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;

  insert into public.ride_payment_operational_alerts(
    dedupe_key, alert_type, severity, details
  )
  select 'mollie-refund-balance', 'mollie_refund_balance_low', 'critical',
    jsonb_build_object('available_balance_cents', h.available_balance_cents)
  from public.mollie_marketplace_health h
  where h.singleton and h.available_balance_cents is not null
    and h.available_balance_cents < coalesce((
      select (nullif(ac.value, '')::jsonb ->> 'minimum_refund_balance_cents')::integer
      from public.app_config ac where ac.key = 'ride_prepaid_payment_config'
    ), 0)
  on conflict (dedupe_key) do update set last_detected_at = excluded.last_detected_at,
    details = excluded.details, resolved_at = null;
  get diagnostics v_count = row_count; v_inserted := v_inserted + v_count;
  return v_inserted;
end;
$$;
revoke all on function public.fn_scan_ride_payment_alerts()
  from public, anon, authenticated;
grant execute on function public.fn_scan_ride_payment_alerts() to service_role;

do $schedule$
begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobid) from cron.job where jobname = 'ride-payment-alert-scan';
    perform cron.schedule(
      'ride-payment-alert-scan', '*/5 * * * *',
      'select public.fn_scan_ride_payment_alerts();'
    );
  end if;
end;
$schedule$;
