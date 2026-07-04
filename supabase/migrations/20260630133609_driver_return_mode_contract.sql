-- Return Mode V1 contract.
-- This stores the driver's active intent server-side without changing dispatch
-- or auto-accept matching. Matching/auto-accept rules remain a later rollout.

alter table public.drivers
  add column if not exists return_mode_enabled boolean not null default false,
  add column if not exists return_mode_auto_accept_enabled boolean not null default false,
  add column if not exists return_mode_destination_zone_id uuid,
  add column if not exists return_mode_destination_label text,
  add column if not exists return_mode_destination_lat double precision,
  add column if not exists return_mode_destination_lng double precision,
  add column if not exists return_mode_activated_at timestamptz,
  add column if not exists return_mode_disabled_at timestamptz,
  add column if not exists return_mode_last_prompt_at timestamptz,
  add column if not exists return_mode_prompt_dismissed_until timestamptz;

create index if not exists idx_drivers_return_mode_enabled
  on public.drivers (return_mode_enabled)
  where return_mode_enabled is true;

create table if not exists public.driver_return_mode_events (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id) on delete cascade,
  event_type text not null check (
    event_type in (
      'return_mode.prompt_shown',
      'return_mode.activated',
      'return_mode.dismissed',
      'return_mode.disabled',
      'return_mode.auto_accept_enabled',
      'return_mode.auto_accept_disabled',
      'return_ride.qualified',
      'return_ride.skipped',
      'return_ride.accepted'
    )
  ),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_driver_return_mode_events_driver_created
  on public.driver_return_mode_events (driver_id, created_at desc);

comment on table public.driver_return_mode_events is
  'Audit trail for Return Mode intent, prompts, and future return-ride matching decisions.';

alter table public.driver_return_mode_events enable row level security;

drop policy if exists driver_return_mode_events_select_own
  on public.driver_return_mode_events;
create policy driver_return_mode_events_select_own
  on public.driver_return_mode_events
  for select
  to authenticated
  using (
    driver_id in (
      select d.id from public.drivers d where d.user_id = auth.uid()
    )
  );

drop policy if exists driver_return_mode_events_admin_select
  on public.driver_return_mode_events;
create policy driver_return_mode_events_admin_select
  on public.driver_return_mode_events
  for select
  to authenticated
  using (
    exists (select 1 from public.admin_users au where au.user_id = auth.uid())
  );

revoke all on public.driver_return_mode_events from public;
grant select on public.driver_return_mode_events to authenticated, service_role;

create or replace function public.fn_driver_return_mode_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_driver record;
  v_destination_label text;
  v_pickup_radius numeric;
  v_discount numeric;
  v_can_prompt boolean;
begin
  select
    d.id,
    d.return_mode_enabled,
    d.return_mode_auto_accept_enabled,
    d.return_mode_destination_zone_id,
    d.return_mode_destination_label,
    d.return_mode_destination_lat,
    d.return_mode_destination_lng,
    d.return_mode_activated_at,
    d.return_mode_disabled_at,
    d.return_mode_last_prompt_at,
    d.return_mode_prompt_dismissed_until,
    d.heading_home_zone_id,
    d.home_city,
    d.pickup_distance_max_km,
    d.active_return_discount_pct
  into v_driver
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_driver.id is null then
    return jsonb_build_object('ok', false, 'error', 'driver_not_found');
  end if;

  v_destination_label := nullif(trim(coalesce(
    v_driver.return_mode_destination_label,
    v_driver.home_city,
    ''
  )), '');
  v_pickup_radius := coalesce(v_driver.pickup_distance_max_km, 10);
  v_discount := coalesce(v_driver.active_return_discount_pct, 0);
  v_can_prompt :=
    coalesce(v_driver.return_mode_enabled, false) is false
    and v_destination_label is not null
    and (
      v_driver.return_mode_prompt_dismissed_until is null
      or v_driver.return_mode_prompt_dismissed_until <= now()
    );

  return jsonb_build_object(
    'ok', true,
    'enabled', coalesce(v_driver.return_mode_enabled, false),
    'auto_accept_enabled', coalesce(v_driver.return_mode_auto_accept_enabled, false),
    'destination_zone_id', coalesce(
      v_driver.return_mode_destination_zone_id,
      v_driver.heading_home_zone_id
    ),
    'destination_label', v_destination_label,
    'destination_lat', v_driver.return_mode_destination_lat,
    'destination_lng', v_driver.return_mode_destination_lng,
    'pickup_radius_km', v_pickup_radius,
    'return_discount_pct', v_discount,
    'activated_at', v_driver.return_mode_activated_at,
    'disabled_at', v_driver.return_mode_disabled_at,
    'last_prompt_at', v_driver.return_mode_last_prompt_at,
    'prompt_dismissed_until', v_driver.return_mode_prompt_dismissed_until,
    'can_prompt', v_can_prompt
  );
end;
$$;

create or replace function public.fn_driver_return_mode_activate(
  p_destination_label text default null,
  p_destination_zone_id uuid default null,
  p_destination_lat double precision default null,
  p_destination_lng double precision default null,
  p_pickup_radius_km numeric default null,
  p_return_discount_pct numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver record;
  v_profile_id uuid;
  v_destination_label text;
  v_pickup_radius numeric;
  v_discount numeric;
begin
  select
    d.id,
    d.home_city,
    d.pickup_distance_max_km,
    d.active_return_discount_pct
  into v_driver
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_driver.id is null then
    return jsonb_build_object('ok', false, 'error', 'driver_not_found');
  end if;

  v_destination_label := nullif(trim(coalesce(
    p_destination_label,
    v_driver.home_city,
    ''
  )), '');
  if v_destination_label is null then
    return jsonb_build_object('ok', false, 'error', 'missing_return_destination');
  end if;

  v_pickup_radius := least(greatest(coalesce(
    p_pickup_radius_km,
    v_driver.pickup_distance_max_km,
    10
  ), 1), 50);
  v_discount := least(greatest(coalesce(
    p_return_discount_pct,
    nullif(v_driver.active_return_discount_pct, 0),
    15
  ), 0), 40);

  update public.drivers d
  set
    return_mode_enabled = true,
    return_mode_auto_accept_enabled = false,
    return_mode_destination_label = v_destination_label,
    return_mode_destination_zone_id = p_destination_zone_id,
    return_mode_destination_lat = p_destination_lat,
    return_mode_destination_lng = p_destination_lng,
    return_mode_activated_at = now(),
    return_mode_disabled_at = null,
    pickup_distance_max_km = v_pickup_radius,
    updated_at = now()
  where d.id = v_driver.id;

  select p.id into v_profile_id
  from public.driver_rate_profiles p
  where p.driver_id = v_driver.id and p.is_active is true
  order by p.updated_at desc nulls last
  limit 1;

  if v_profile_id is not null then
    update public.driver_rate_profiles p
    set return_discount_pct = v_discount,
        updated_at = now()
    where p.id = v_profile_id;
  else
    update public.drivers d
    set active_return_discount_pct = v_discount
    where d.id = v_driver.id;
  end if;

  insert into public.driver_return_mode_events (driver_id, event_type, payload)
  values (
    v_driver.id,
    'return_mode.activated',
    jsonb_build_object(
      'destination_label', v_destination_label,
      'destination_zone_id', p_destination_zone_id,
      'pickup_radius_km', v_pickup_radius,
      'return_discount_pct', v_discount,
      'auto_accept_enabled', false
    )
  );

  return public.fn_driver_return_mode_status();
end;
$$;

create or replace function public.fn_driver_return_mode_disable()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select d.id into v_driver_id
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_driver_id is null then
    return jsonb_build_object('ok', false, 'error', 'driver_not_found');
  end if;

  update public.drivers d
  set
    return_mode_enabled = false,
    return_mode_auto_accept_enabled = false,
    return_mode_disabled_at = now(),
    updated_at = now()
  where d.id = v_driver_id;

  insert into public.driver_return_mode_events (driver_id, event_type)
  values (v_driver_id, 'return_mode.disabled');

  return public.fn_driver_return_mode_status();
end;
$$;

create or replace function public.fn_driver_return_mode_dismiss_prompt(
  p_cooldown_hours integer default 24
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver_id uuid;
  v_cooldown_hours integer;
begin
  select d.id into v_driver_id
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_driver_id is null then
    return jsonb_build_object('ok', false, 'error', 'driver_not_found');
  end if;

  v_cooldown_hours := least(greatest(coalesce(p_cooldown_hours, 24), 1), 168);

  update public.drivers d
  set
    return_mode_prompt_dismissed_until = now() + make_interval(hours => v_cooldown_hours),
    return_mode_last_prompt_at = now(),
    updated_at = now()
  where d.id = v_driver_id;

  insert into public.driver_return_mode_events (driver_id, event_type, payload)
  values (
    v_driver_id,
    'return_mode.dismissed',
    jsonb_build_object('cooldown_hours', v_cooldown_hours)
  );

  return public.fn_driver_return_mode_status();
end;
$$;

create or replace function public.fn_driver_return_mode_prompt_shown()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select d.id into v_driver_id
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_driver_id is null then
    return jsonb_build_object('ok', false, 'error', 'driver_not_found');
  end if;

  update public.drivers d
  set return_mode_last_prompt_at = now(),
      updated_at = now()
  where d.id = v_driver_id;

  insert into public.driver_return_mode_events (driver_id, event_type)
  values (v_driver_id, 'return_mode.prompt_shown');

  return public.fn_driver_return_mode_status();
end;
$$;

revoke all on function public.fn_driver_return_mode_status() from public;
revoke all on function public.fn_driver_return_mode_activate(text, uuid, double precision, double precision, numeric, numeric) from public;
revoke all on function public.fn_driver_return_mode_disable() from public;
revoke all on function public.fn_driver_return_mode_dismiss_prompt(integer) from public;
revoke all on function public.fn_driver_return_mode_prompt_shown() from public;

grant execute on function public.fn_driver_return_mode_status() to authenticated, service_role;
grant execute on function public.fn_driver_return_mode_activate(text, uuid, double precision, double precision, numeric, numeric) to authenticated, service_role;
grant execute on function public.fn_driver_return_mode_disable() to authenticated, service_role;
grant execute on function public.fn_driver_return_mode_dismiss_prompt(integer) to authenticated, service_role;
grant execute on function public.fn_driver_return_mode_prompt_shown() to authenticated, service_role;
