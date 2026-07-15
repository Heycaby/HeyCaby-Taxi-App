-- Disposable PostgreSQL harness for the canonical ride-start prepayment guard.
-- It supplies only the production-shaped columns and helpers used by the RPC.
\set ON_ERROR_STOP on

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end;
$$;

create schema private;
create domain public.geography as text;

create function public.st_makepoint(double precision, double precision)
returns text language sql immutable as $$ select 'point'::text $$;
create function public.st_setsrid(text, integer)
returns text language sql immutable as $$ select $1 $$;
create function public.st_distance(public.geography, public.geography)
returns numeric language sql immutable as $$ select 0::numeric $$;

create table public.app_config (
  key text primary key,
  value text
);

create table public.ride_requests (
  id uuid primary key,
  driver_id uuid,
  status text not null,
  booking_mode text not null,
  payment_status text,
  pickup_coords public.geography,
  driver_arrived_at timestamptz,
  waiting_grace_seconds integer default 120,
  waiting_fee_waived boolean default false,
  waiting_rate_per_minute numeric default 0,
  chargeable_wait_seconds integer default 0,
  waiting_fee_cents integer default 0,
  started_at timestamptz,
  updated_at timestamptz default now()
);

create table public.ride_payments (
  id uuid primary key,
  ride_id uuid not null,
  state text not null,
  paid_at timestamptz,
  refunded_cents integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.driver_locations (
  driver_id uuid,
  longitude double precision,
  latitude double precision,
  updated_at timestamptz
);

create table public.ride_audit_log (
  ride_id uuid,
  event text,
  actor_id uuid,
  metadata jsonb,
  actor_type text,
  source text,
  correlation_id uuid
);

create function public.fn_app_config_text(p_key text)
returns text language sql stable as $$
  select ac.value from public.app_config ac where ac.key = p_key
$$;

create function public.fn_driver_ride_lifecycle_resolve_driver()
returns uuid language sql stable as $$
  select '10000000-0000-0000-0000-000000000001'::uuid
$$;

create function public.fn_ride_audit_append(
  p_ride_id uuid,
  p_event text,
  p_actor_id uuid,
  p_metadata jsonb,
  p_actor_type text,
  p_source text,
  p_correlation_id uuid
)
returns void language sql as $$
  insert into public.ride_audit_log (
    ride_id, event, actor_id, metadata, actor_type, source, correlation_id
  ) values (
    p_ride_id, p_event, p_actor_id, p_metadata, p_actor_type, p_source,
    p_correlation_id
  )
$$;

create function public.fn_driver_ride_lifecycle_mark_on_ride(uuid)
returns void language sql as $$ select $$;

create function public.fn_driver_ride_lifecycle_audit(
  uuid, text, uuid, jsonb
)
returns void language sql as $$ select $$;

create function public.fn_ride_notify_rider(
  uuid, text, text, text, jsonb, text
)
returns void language sql as $$ select $$;

\ir ../migrations/20260714224454_enforce_required_ride_prepayment_on_start.sql
\ir ride_prepayment_start_guard_test.sql
