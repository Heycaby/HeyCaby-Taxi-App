-- Minimal disposable PostgreSQL harness for the Vault-backed Rider lifecycle
-- cron boundary. It models only the schemas/signatures used by the migration.

create role anon;
create role authenticated;
create role service_role;

create schema private;
create schema vault;
create schema net;
create schema cron;

create table public.app_config (
  key text primary key,
  value text not null
);

create table private.domain_security_events (
  id uuid primary key default gen_random_uuid(),
  domain text not null,
  event text not null,
  metadata jsonb not null default '{}'::jsonb
);

create table vault.decrypted_secrets (
  name text primary key,
  decrypted_secret text not null
);

create table cron.job (
  jobid bigint primary key,
  jobname text unique not null,
  schedule text not null,
  command text not null,
  database text,
  username text,
  active boolean not null default true
);

create function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds integer default 5000
)
returns bigint
language sql
as $$ select 42::bigint $$;

create function cron.alter_job(
  job_id bigint,
  schedule text default null,
  command text default null,
  database text default null,
  username text default null,
  active boolean default null
)
returns void
language plpgsql
as $$
begin
  update cron.job j
  set schedule = coalesce($2, j.schedule),
      command = coalesce($3, j.command),
      database = coalesce($4, j.database),
      username = coalesce($5, j.username),
      active = coalesce($6, j.active)
  where j.jobid = $1;
end;
$$;

insert into public.app_config(key, value)
values (
  'rider_agent_webhook_url',
  'https://example.supabase.co/functions/v1/rider-agent'
);

insert into vault.decrypted_secrets(name, decrypted_secret)
values ('rider_agent_webhook_secret', 'test-only-secret');

insert into cron.job(jobid, jobname, schedule, command)
values (
  5,
  'rider-lifecycle-dispatch-every-20m',
  '*/20 * * * *',
  'select net.http_post(headers := jsonb_build_object(''x-webhook-secret'', ''legacy''));'
);

grant usage on schema private to service_role;
