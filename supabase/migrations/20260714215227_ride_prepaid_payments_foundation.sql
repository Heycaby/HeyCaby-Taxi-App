-- Ride prepayments are intentionally separate from Driver Platform Balance.
-- The feature flags are disabled by default so deploying this migration cannot
-- change any existing cash, PIN, Tikkie, scheduled, or Taxi Terug flow.

insert into public.app_config (key, value)
values (
  'feature_flags',
  jsonb_build_object(
    'ride_prepaid_payments_enabled', false,
    'ride_prepaid_scheduled_enabled', false,
    'ride_prepaid_taxi_terug_enabled', false,
    'ride_prepaid_instant_optional_enabled', false
  )::text
)
on conflict (key) do update
set value = (
  jsonb_build_object(
    'ride_prepaid_payments_enabled', false,
    'ride_prepaid_scheduled_enabled', false,
    'ride_prepaid_taxi_terug_enabled', false,
    'ride_prepaid_instant_optional_enabled', false
  ) || coalesce(nullif(public.app_config.value, '')::jsonb, '{}'::jsonb)
)::text;

insert into public.app_config (key, value)
values (
  'ride_prepaid_payment_config',
  jsonb_build_object(
    'currency', 'EUR',
    'platform_fee_bps', 0,
    'free_cancellation_minutes', 0,
    'late_cancellation_fee_bps', 0,
    'routing_mode', 'delayed',
    'environment', 'test'
  )::text
)
on conflict (key) do nothing;

create table if not exists public.driver_mollie_connections (
  driver_id uuid primary key references public.drivers(id) on delete cascade,
  organization_id text unique,
  status text not null default 'pending'
    check (status in ('pending', 'connected', 'onboarding', 'verified', 'restricted', 'disabled', 'revoked')),
  onboarding_status text,
  can_receive_prepaid_rides boolean not null default false,
  access_token_ciphertext text,
  refresh_token_ciphertext text,
  token_expires_at timestamptz,
  scopes text[] not null default '{}'::text[],
  connected_at timestamptz,
  verified_at timestamptz,
  disabled_at timestamptz,
  last_synced_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint driver_mollie_tokens_together check (
    (access_token_ciphertext is null) = (refresh_token_ciphertext is null)
  )
);

create table if not exists public.mollie_oauth_states (
  state_hash text primary key,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  redirect_uri text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.driver_mollie_connections is
  'Finance-owned Mollie Connect projection. OAuth tokens are application-encrypted before storage; clients never read this table.';

create table if not exists public.ride_payments (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.ride_requests(id) on delete restrict,
  rider_identity_id uuid references public.rider_identities(id) on delete set null,
  driver_id uuid not null references public.drivers(id) on delete restrict,
  provider text not null default 'mollie' check (provider = 'mollie'),
  provider_payment_id text,
  provider_customer_id text,
  state text not null default 'creating' check (state in (
    'creating', 'open', 'pending', 'authorized', 'paid', 'failed',
    'canceled', 'expired', 'partially_refunded', 'refunded',
    'routing_pending', 'routed', 'routing_failed'
  )),
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  platform_fee_cents integer not null default 0 check (platform_fee_cents >= 0),
  driver_route_cents integer not null check (driver_route_cents >= 0),
  checkout_url text,
  idempotency_key uuid not null,
  correlation_id uuid not null default gen_random_uuid(),
  fare_snapshot jsonb not null,
  provider_snapshot jsonb not null default '{}'::jsonb,
  failure_code text,
  paid_at timestamptz,
  expires_at timestamptz,
  refunded_cents integer not null default 0 check (refunded_cents >= 0),
  routed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint ride_payment_split_matches_total check (
    platform_fee_cents + driver_route_cents = amount_cents
  ),
  constraint ride_payment_refund_not_over_total check (refunded_cents <= amount_cents),
  unique (provider, provider_payment_id),
  unique (idempotency_key)
);

create unique index if not exists ride_payments_one_live_payment_per_ride
  on public.ride_payments (ride_id)
  where state not in ('failed', 'canceled', 'expired', 'refunded');

create index if not exists ride_payments_ride_created_idx
  on public.ride_payments (ride_id, created_at desc);
create index if not exists ride_payments_driver_state_idx
  on public.ride_payments (driver_id, state, created_at desc);

create table if not exists public.ride_payment_events (
  id uuid primary key default gen_random_uuid(),
  ride_payment_id uuid not null references public.ride_payments(id) on delete restrict,
  ride_id uuid not null references public.ride_requests(id) on delete restrict,
  event_type text not null,
  provider_event_key text,
  from_state text,
  to_state text,
  actor_type text not null default 'system',
  actor_id uuid,
  source text not null,
  correlation_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default timezone('utc', now()),
  unique (source, provider_event_key)
);

create index if not exists ride_payment_events_ride_time_idx
  on public.ride_payment_events (ride_id, occurred_at, id);

create table if not exists public.ride_payment_refunds (
  id uuid primary key default gen_random_uuid(),
  ride_payment_id uuid not null references public.ride_payments(id) on delete restrict,
  provider_refund_id text,
  amount_cents integer not null check (amount_cents > 0),
  state text not null default 'creating'
    check (state in ('creating', 'pending', 'refunded', 'failed', 'canceled')),
  reason_code text not null,
  idempotency_key uuid not null unique,
  provider_snapshot jsonb not null default '{}'::jsonb,
  requested_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (provider_refund_id)
);

create table if not exists public.ride_payment_routes (
  id uuid primary key default gen_random_uuid(),
  ride_payment_id uuid not null references public.ride_payments(id) on delete restrict,
  provider_route_id text,
  organization_id text not null,
  amount_cents integer not null check (amount_cents > 0),
  state text not null default 'creating'
    check (state in ('creating', 'pending', 'routed', 'failed', 'reversed')),
  idempotency_key uuid not null unique,
  provider_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (provider_route_id)
);

alter table public.driver_mollie_connections enable row level security;
alter table public.mollie_oauth_states enable row level security;
alter table public.ride_payments enable row level security;
alter table public.ride_payment_events enable row level security;
alter table public.ride_payment_refunds enable row level security;
alter table public.ride_payment_routes enable row level security;

revoke all on public.driver_mollie_connections from anon, authenticated;
revoke all on public.mollie_oauth_states from anon, authenticated;
revoke all on public.ride_payments from anon, authenticated;
revoke all on public.ride_payment_events from anon, authenticated;
revoke all on public.ride_payment_refunds from anon, authenticated;
revoke all on public.ride_payment_routes from anon, authenticated;

create or replace function public.fn_driver_mollie_connection_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_driver_id uuid;
  v_connection public.driver_mollie_connections%rowtype;
begin
  select d.id into v_driver_id
  from public.drivers d
  where d.user_id = auth.uid();

  if v_driver_id is null then
    return jsonb_build_object('ok', false, 'error', 'not_a_driver');
  end if;

  select * into v_connection
  from public.driver_mollie_connections c
  where c.driver_id = v_driver_id;

  return jsonb_build_object(
    'ok', true,
    'connected', v_connection.driver_id is not null,
    'status', coalesce(v_connection.status, 'not_connected'),
    'onboarding_status', v_connection.onboarding_status,
    'can_receive_prepaid_rides', coalesce(v_connection.can_receive_prepaid_rides, false),
    'last_synced_at', v_connection.last_synced_at,
    'last_error_code', v_connection.last_error_code
  );
end;
$$;

revoke all on function public.fn_driver_mollie_connection_status() from public, anon;
grant execute on function public.fn_driver_mollie_connection_status() to authenticated;

create or replace function public.fn_ride_payment_snapshot(
  p_ride_id uuid,
  p_rider_token text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ride public.ride_requests%rowtype;
  v_payment public.ride_payments%rowtype;
  v_is_driver boolean := false;
  v_is_rider boolean := false;
begin
  select * into v_ride from public.ride_requests where id = p_ride_id;
  if v_ride.id is null then
    return jsonb_build_object('ok', false, 'error', 'ride_not_found');
  end if;

  v_is_driver := exists (
    select 1 from public.drivers d
    where d.id = v_ride.driver_id and d.user_id = auth.uid()
  );
  v_is_rider := (
    p_rider_token is not null
    and v_ride.rider_token is not null
    and p_rider_token = v_ride.rider_token
  ) or exists (
    select 1 from public.rider_identities ri
    where ri.id = v_ride.rider_identity_id and ri.user_id = auth.uid()
  );

  if not v_is_driver and not v_is_rider then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;

  select * into v_payment
  from public.ride_payments p
  where p.ride_id = p_ride_id
  order by p.created_at desc
  limit 1;

  if v_payment.id is null then
    return jsonb_build_object('ok', true, 'payment', null);
  end if;

  return jsonb_build_object('ok', true, 'payment', jsonb_build_object(
    'id', v_payment.id,
    'state', v_payment.state,
    'amount_cents', v_payment.amount_cents,
    'currency', v_payment.currency,
    'checkout_url', case when v_is_rider then v_payment.checkout_url else null end,
    'paid_at', v_payment.paid_at,
    'refunded_cents', v_payment.refunded_cents,
    'created_at', v_payment.created_at,
    'updated_at', v_payment.updated_at
  ));
end;
$$;

revoke all on function public.fn_ride_payment_snapshot(uuid, text) from public, anon;
grant execute on function public.fn_ride_payment_snapshot(uuid, text) to authenticated;

-- Edge Functions call this service-role-only command after re-fetching the
-- payment from Mollie. The provider payload itself is never trusted.
create or replace function public.fn_ride_payment_apply_provider_snapshot(
  p_provider_payment_id text,
  p_provider_event_key text,
  p_provider_status text,
  p_amount_cents integer,
  p_currency text,
  p_provider_snapshot jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.ride_payments%rowtype;
  v_target_state text;
  v_now timestamptz := timezone('utc', now());
begin
  select * into v_payment
  from public.ride_payments
  where provider = 'mollie' and provider_payment_id = p_provider_payment_id
  for update;

  if v_payment.id is null then
    return jsonb_build_object('ok', false, 'error', 'payment_not_found');
  end if;
  if p_amount_cents <> v_payment.amount_cents or upper(p_currency) <> v_payment.currency then
    insert into public.ride_payment_events (
      ride_payment_id, ride_id, event_type, provider_event_key, from_state,
      to_state, source, correlation_id, payload
    ) values (
      v_payment.id, v_payment.ride_id, 'provider_snapshot_rejected',
      p_provider_event_key, v_payment.state, v_payment.state,
      'mollie_webhook', v_payment.correlation_id,
      jsonb_build_object('reason', 'amount_or_currency_mismatch')
    ) on conflict (source, provider_event_key) do nothing;
    return jsonb_build_object('ok', false, 'error', 'amount_or_currency_mismatch');
  end if;

  v_target_state := case lower(p_provider_status)
    when 'open' then 'open'
    when 'pending' then 'pending'
    when 'authorized' then 'authorized'
    when 'paid' then 'paid'
    when 'failed' then 'failed'
    when 'canceled' then 'canceled'
    when 'expired' then 'expired'
    else null
  end;
  if v_target_state is null then
    return jsonb_build_object('ok', false, 'error', 'unsupported_provider_status');
  end if;

  insert into public.ride_payment_events (
    ride_payment_id, ride_id, event_type, provider_event_key, from_state,
    to_state, source, correlation_id, payload
  ) values (
    v_payment.id, v_payment.ride_id, 'provider_status_observed',
    p_provider_event_key, v_payment.state, v_target_state,
    'mollie_webhook', v_payment.correlation_id, p_provider_snapshot
  ) on conflict (source, provider_event_key) do nothing;

  if not found then
    return jsonb_build_object('ok', true, 'idempotent_replay', true, 'state', v_payment.state);
  end if;

  -- Paid is terminal with respect to late failed/canceled/expired webhooks.
  if v_payment.state in ('paid', 'routing_pending', 'routed', 'partially_refunded', 'refunded')
     and v_target_state in ('open', 'pending', 'authorized', 'failed', 'canceled', 'expired') then
    return jsonb_build_object('ok', true, 'ignored_stale_transition', true, 'state', v_payment.state);
  end if;

  update public.ride_payments
  set state = v_target_state,
      provider_snapshot = coalesce(p_provider_snapshot, '{}'::jsonb),
      paid_at = case when v_target_state = 'paid' then coalesce(paid_at, v_now) else paid_at end,
      updated_at = v_now
  where id = v_payment.id;

  if v_target_state = 'paid' then
    update public.ride_requests
    set payment_status = 'confirmed',
        rider_payment_confirmed_at = coalesce(rider_payment_confirmed_at, v_now),
        payment_confirmed_at = coalesce(payment_confirmed_at, v_now)
    where id = v_payment.ride_id;

    insert into public.ride_audit_log (
      ride_id, event, occurred_at, metadata, correlation_id, actor_type, source
    ) values (
      v_payment.ride_id, 'payment.prepaid_paid', v_now,
      jsonb_build_object(
        'ride_payment_id', v_payment.id,
        'amount_cents', v_payment.amount_cents,
        'currency', v_payment.currency,
        'provider', 'mollie'
      ),
      v_payment.correlation_id, 'system', 'mollie_webhook'
    );
  end if;

  return jsonb_build_object('ok', true, 'state', v_target_state, 'ride_id', v_payment.ride_id);
end;
$$;

revoke all on function public.fn_ride_payment_apply_provider_snapshot(text, text, text, integer, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.fn_ride_payment_apply_provider_snapshot(text, text, text, integer, text, jsonb)
  to service_role;
