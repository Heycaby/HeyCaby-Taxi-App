-- Driver Hub: "Suggestion for the app"
-- Drivers can submit feature requests. Team can review/vote/plan.

create table if not exists public.driver_app_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  driver_id uuid references public.drivers(id) on delete set null,
  suggestion_text text not null check (char_length(trim(suggestion_text)) between 10 and 1200),
  status text not null default 'new' check (status in ('new', 'reviewing', 'planned', 'in_progress', 'done', 'rejected')),
  votes_count integer not null default 0 check (votes_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_driver_app_suggestions_created_at
  on public.driver_app_suggestions(created_at desc);

create index if not exists idx_driver_app_suggestions_status
  on public.driver_app_suggestions(status);

alter table public.driver_app_suggestions enable row level security;

drop policy if exists "driver_app_suggestions_insert_own" on public.driver_app_suggestions;
create policy "driver_app_suggestions_insert_own"
  on public.driver_app_suggestions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "driver_app_suggestions_select_own" on public.driver_app_suggestions;
create policy "driver_app_suggestions_select_own"
  on public.driver_app_suggestions
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "driver_app_suggestions_service_role_all" on public.driver_app_suggestions;
create policy "driver_app_suggestions_service_role_all"
  on public.driver_app_suggestions
  for all
  to service_role
  using (true)
  with check (true);

create or replace function public.set_driver_app_suggestions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_driver_app_suggestions_updated_at on public.driver_app_suggestions;
create trigger trg_driver_app_suggestions_updated_at
before update on public.driver_app_suggestions
for each row execute function public.set_driver_app_suggestions_updated_at();
