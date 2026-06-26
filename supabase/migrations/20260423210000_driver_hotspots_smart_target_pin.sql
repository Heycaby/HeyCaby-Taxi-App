-- Smart Target Pin backend for Driver Radar / Hotspots.
-- Adds curated hotspot points and an RPC that returns demand zones
-- with the best weighted navigation target per zone.

create table if not exists public.zone_smart_targets (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references public.bubble_zones(id) on delete cascade,
  label text not null,
  category text not null check (category in ('station', 'nightlife', 'airport', 'event', 'transit', 'city_center')),
  target_lat double precision not null check (target_lat between -90 and 90),
  target_lng double precision not null check (target_lng between -180 and 180),
  base_weight numeric(6,2) not null default 1.00,
  active_from time,
  active_to time,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_zone_smart_targets_zone_active
  on public.zone_smart_targets(zone_id, is_active);

create index if not exists idx_zone_smart_targets_category
  on public.zone_smart_targets(category);

alter table public.zone_smart_targets enable row level security;

drop policy if exists "zone_smart_targets_select_authenticated" on public.zone_smart_targets;
create policy "zone_smart_targets_select_authenticated"
  on public.zone_smart_targets
  for select
  to authenticated
  using (is_active = true);

drop policy if exists "zone_smart_targets_service_role_all" on public.zone_smart_targets;
create policy "zone_smart_targets_service_role_all"
  on public.zone_smart_targets
  for all
  to service_role
  using (true)
  with check (true);

create or replace function public.set_zone_smart_targets_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_zone_smart_targets_updated_at on public.zone_smart_targets;
create trigger trg_zone_smart_targets_updated_at
before update on public.zone_smart_targets
for each row execute function public.set_zone_smart_targets_updated_at();

create or replace function public.fn_driver_hotspots_smart()
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
  smart_target_score numeric
)
language sql
stable
security invoker
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
    avg(st_y(rr.pickup_point::geometry))::double precision as recent_pickup_lat,
    avg(st_x(rr.pickup_point::geometry))::double precision as recent_pickup_lng,
    avg(coalesce(rr.offered_fare, 0))::numeric as avg_offered_fare
  from public.ride_requests rr
  where rr.zone_id is not null
    and rr.pickup_point is not null
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
  coalesce(b.score, 0)::numeric as smart_target_score
from demand d
left join best_candidate b on b.zone_id = d.zone_id
left join recent_rides r on r.zone_id = d.zone_id
order by d.waiting_passengers desc, d.zone_name asc;
$$;

grant execute on function public.fn_driver_hotspots_smart() to authenticated;
grant execute on function public.fn_driver_hotspots_smart() to service_role;
