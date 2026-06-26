-- Hotspots: expose real aggregates from ride_requests + driver_locations (RPC runs as
-- SECURITY DEFINER so zone-level counts are not blinded by per-user RLS).
-- Tariffs: audit log + secure RPC for rate edits (syncs drivers row when profile active).

-- ── Audit table (append-only) ─────────────────────────────────────────────
create table if not exists public.driver_tariff_events (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id) on delete cascade,
  profile_id uuid references public.driver_rate_profiles (id) on delete set null,
  event_type text not null check (event_type in ('switch_profile', 'rate_edit')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_driver_tariff_events_driver_created
  on public.driver_tariff_events (driver_id, created_at desc);

comment on table public.driver_tariff_events is
  'Per-driver tariff switches and rate edits for support/analytics; written only from SECURITY DEFINER RPCs.';

alter table public.driver_tariff_events enable row level security;

drop policy if exists "driver_tariff_events_select_own" on public.driver_tariff_events;
create policy "driver_tariff_events_select_own"
  on public.driver_tariff_events
  for select
  to authenticated
  using (
    driver_id in (
      select d.id from public.drivers d where d.user_id = auth.uid()
    )
  );

revoke all on public.driver_tariff_events from anon;

-- ── Hotspots RPC: add live metrics + SECURITY DEFINER ─────────────────────
-- OUT signature changed — must drop first.
drop function if exists public.fn_driver_hotspots_smart();

create function public.fn_driver_hotspots_smart()
returns table (
  zone_id uuid,
  zone_name text,
  center_lat double precision,
  center_lng double precision,
  radius_m double precision,
  waiting_passengers integer,
  demand_level text,
  smart_target_lat double precision,
  smart_target_lng double precision,
  smart_target_label text,
  smart_target_reason text,
  smart_target_score numeric,
  recent_bookings_120m integer,
  avg_offered_fare_eur numeric,
  online_drivers_in_zone integer
)
language sql
stable
security definer
set search_path = public
as $$
with demand as (
  select
    z.zone_id::uuid as zone_id,
    z.zone_name,
    z.center_lat,
    z.center_lng,
    z.radius_m,
    z.waiting_passengers,
    z.demand_level
  from public.zone_demand_live z
),
recent_rides as (
  select
    rr.zone_id::uuid as zone_id,
    count(*)::int as recent_bookings,
    avg(rr.pickup_lat)::double precision as recent_pickup_lat,
    avg(rr.pickup_lng)::double precision as recent_pickup_lng,
    avg(nullif(rr.offered_fare, 0))::numeric as avg_offered_fare
  from public.ride_requests rr
  where rr.zone_id is not null
    and rr.pickup_lat is not null
    and rr.pickup_lng is not null
    and rr.created_at >= now() - interval '120 minutes'
  group by rr.zone_id
),
signal_stats as (
  select
    s.zone_id::uuid as zone_id,
    count(*) filter (where s.signal_type = 'event')::int as event_signals,
    count(*) filter (where s.signal_type = 'high_demand')::int as high_demand_signals
  from public.driver_market_signals s
  where s.created_at >= now() - interval '180 minutes'
  group by s.zone_id
),
online_by_zone as (
  select
    dl.current_zone_id::uuid as zone_id,
    count(distinct dl.driver_id)::int as online_drivers
  from public.driver_locations dl
  inner join public.drivers d on d.id = dl.driver_id
  where dl.current_zone_id is not null
    and dl.updated_at >= now() - interval '3 minutes'
    and d.status in ('available', 'on_ride')
  group by dl.current_zone_id
),
candidate_points as (
  select
    t.zone_id,
    t.target_lat,
    t.target_lng,
    t.label,
    t.category,
    (
      t.base_weight
      + case t.category
          when 'station' then 2.60
          when 'airport' then 2.90
          when 'event' then 3.20
          when 'nightlife' then case
            when (localtime >= time '18:00' or localtime <= time '03:00') then 3.40
            else 1.10
          end
          when 'transit' then 1.70
          else 1.20
        end
      + least(coalesce(r.recent_bookings, 0) * 0.12, 2.50)
      + least(coalesce(s.event_signals, 0) * 0.45, 1.80)
      + least(coalesce(s.high_demand_signals, 0) * 0.35, 1.60)
    )::numeric as score
  from public.zone_smart_targets t
  left join recent_rides r on r.zone_id = t.zone_id
  left join signal_stats s on s.zone_id = t.zone_id
  where t.is_active = true
    and (
      t.active_from is null
      or t.active_to is null
      or (t.active_from <= t.active_to and localtime between t.active_from and t.active_to)
      or (t.active_from > t.active_to and (localtime >= t.active_from or localtime <= t.active_to))
    )
),
best_candidate as (
  select distinct on (c.zone_id)
    c.zone_id,
    c.target_lat,
    c.target_lng,
    c.label,
    c.category,
    c.score
  from candidate_points c
  order by c.zone_id, c.score desc, c.label asc
)
select
  d.zone_id,
  d.zone_name,
  d.center_lat,
  d.center_lng,
  d.radius_m,
  d.waiting_passengers,
  d.demand_level,
  coalesce(b.target_lat, r.recent_pickup_lat, d.center_lat) as smart_target_lat,
  coalesce(b.target_lng, r.recent_pickup_lng, d.center_lng) as smart_target_lng,
  coalesce(b.label, d.zone_name, 'Zone target') as smart_target_label,
  case
    when b.zone_id is not null then 'curated_weighted'
    when r.zone_id is not null then 'recent_pickup_centroid'
    else 'zone_center_fallback'
  end as smart_target_reason,
  coalesce(b.score, 0)::numeric as smart_target_score,
  coalesce(r.recent_bookings, 0) as recent_bookings_120m,
  r.avg_offered_fare as avg_offered_fare_eur,
  coalesce(o.online_drivers, 0) as online_drivers_in_zone
from demand d
left join best_candidate b on b.zone_id = d.zone_id
left join recent_rides r on r.zone_id = d.zone_id
left join online_by_zone o on o.zone_id = d.zone_id
order by d.waiting_passengers desc, d.zone_name asc;
$$;

revoke all on function public.fn_driver_hotspots_smart() from public;
grant execute on function public.fn_driver_hotspots_smart() to authenticated;
grant execute on function public.fn_driver_hotspots_smart() to service_role;

-- ── Tariff: log profile switches ────────────────────────────────────────────
create or replace function public.fn_switch_rate_profile(
  p_driver_id uuid,
  p_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_profile record;
  v_auth_driver_id uuid;
  v_old_profile_id uuid;
begin
  select d.id
  into v_auth_driver_id
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_auth_driver_id is null or v_auth_driver_id <> p_driver_id then
    return jsonb_build_object('success', false, 'error', 'forbidden');
  end if;

  select id into v_old_profile_id
  from public.driver_rate_profiles
  where driver_id = p_driver_id
    and is_active = true
  limit 1;

  select *
  into v_profile
  from public.driver_rate_profiles
  where id = p_profile_id
    and driver_id = p_driver_id;

  if v_profile is null then
    return jsonb_build_object('success', false, 'error', 'profile_not_found');
  end if;

  update public.driver_rate_profiles
  set is_active = false,
      updated_at = now()
  where driver_id = p_driver_id;

  update public.driver_rate_profiles
  set is_active = true,
      updated_at = now()
  where id = p_profile_id
    and driver_id = p_driver_id;

  update public.drivers
  set base_fare = v_profile.base_fare,
      per_km_rate = v_profile.per_km_rate,
      per_min_rate = v_profile.per_min_rate,
      minimum_fare = v_profile.minimum_fare,
      waiting_time_rate_per_min = v_profile.waiting_rate,
      updated_at = now()
  where id = p_driver_id;

  insert into public.driver_tariff_events (driver_id, profile_id, event_type, payload)
  values (
    p_driver_id,
    p_profile_id,
    'switch_profile',
    jsonb_build_object(
      'profile_name', v_profile.profile_name,
      'from_profile_id', v_old_profile_id,
      'base_fare', v_profile.base_fare,
      'per_km_rate', v_profile.per_km_rate,
      'per_min_rate', v_profile.per_min_rate,
      'minimum_fare', v_profile.minimum_fare,
      'waiting_rate', v_profile.waiting_rate,
      'return_discount_pct', v_profile.return_discount_pct
    )
  );

  return jsonb_build_object(
    'success', true,
    'profile_id', p_profile_id,
    'profile_name', v_profile.profile_name,
    'base_fare', v_profile.base_fare,
    'per_km_rate', v_profile.per_km_rate,
    'per_min_rate', v_profile.per_min_rate,
    'waiting_rate', v_profile.waiting_rate
  );
end;
$function$;

revoke all on function public.fn_switch_rate_profile(uuid, uuid) from public;
grant execute on function public.fn_switch_rate_profile(uuid, uuid) to authenticated;
grant execute on function public.fn_switch_rate_profile(uuid, uuid) to service_role;

-- ── Tariff: secure rate edit + sync active + audit ─────────────────────────
create or replace function public.fn_update_driver_rate_profile_rates(
  p_driver_id uuid,
  p_profile_id uuid,
  p_base_fare numeric,
  p_per_km_rate numeric,
  p_per_min_rate numeric,
  p_waiting_rate numeric
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_auth uuid;
  v_old record;
  v_is_active boolean;
begin
  select d.id into v_auth
  from public.drivers d
  where d.user_id = auth.uid()
  limit 1;

  if v_auth is null or v_auth <> p_driver_id then
    return jsonb_build_object('success', false, 'error', 'forbidden');
  end if;

  select * into v_old
  from public.driver_rate_profiles
  where id = p_profile_id
    and driver_id = p_driver_id;

  if v_old is null then
    return jsonb_build_object('success', false, 'error', 'profile_not_found');
  end if;

  v_is_active := coalesce(v_old.is_active, false);

  update public.driver_rate_profiles
  set base_fare = p_base_fare,
      per_km_rate = p_per_km_rate,
      per_min_rate = p_per_min_rate,
      waiting_rate = p_waiting_rate,
      updated_at = now()
  where id = p_profile_id
    and driver_id = p_driver_id;

  if v_is_active then
    update public.drivers
    set base_fare = p_base_fare,
        per_km_rate = p_per_km_rate,
        per_min_rate = p_per_min_rate,
        waiting_time_rate_per_min = p_waiting_rate,
        minimum_fare = v_old.minimum_fare,
        updated_at = now()
    where id = p_driver_id;
  end if;

  insert into public.driver_tariff_events (driver_id, profile_id, event_type, payload)
  values (
    p_driver_id,
    p_profile_id,
    'rate_edit',
    jsonb_build_object(
      'profile_name', v_old.profile_name,
      'before', jsonb_build_object(
        'base_fare', v_old.base_fare,
        'per_km_rate', v_old.per_km_rate,
        'per_min_rate', v_old.per_min_rate,
        'waiting_rate', v_old.waiting_rate
      ),
      'after', jsonb_build_object(
        'base_fare', p_base_fare,
        'per_km_rate', p_per_km_rate,
        'per_min_rate', p_per_min_rate,
        'waiting_rate', p_waiting_rate
      ),
      'synced_to_drivers', v_is_active
    )
  );

  return jsonb_build_object('success', true, 'profile_id', p_profile_id);
end;
$function$;

revoke all on function public.fn_update_driver_rate_profile_rates(uuid, uuid, numeric, numeric, numeric, numeric) from public;
grant execute on function public.fn_update_driver_rate_profile_rates(uuid, uuid, numeric, numeric, numeric, numeric) to authenticated;
grant execute on function public.fn_update_driver_rate_profile_rates(uuid, uuid, numeric, numeric, numeric, numeric) to service_role;
