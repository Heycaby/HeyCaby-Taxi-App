create table if not exists public.driver_email_events (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  event_type text not null,
  template_id text not null,
  idempotency_key text not null,
  recipient_email text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null check (status in ('queued', 'sent', 'failed', 'suppressed')),
  provider_message_id text,
  attempt_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists driver_email_events_idempotency_key_uidx
  on public.driver_email_events (idempotency_key);

create index if not exists driver_email_events_driver_status_idx
  on public.driver_email_events (driver_id, status, created_at desc);

create index if not exists driver_email_events_template_idx
  on public.driver_email_events (template_id, created_at desc);
