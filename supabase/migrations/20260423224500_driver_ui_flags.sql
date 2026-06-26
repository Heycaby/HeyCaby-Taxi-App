-- Per-driver UI flags/preferences for dismissible helper modals.

create table if not exists public.driver_ui_flags (
  user_id uuid primary key references auth.users(id) on delete cascade,
  ride_swap_intro_dismissed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.driver_ui_flags enable row level security;

drop policy if exists "driver_ui_flags_select_own" on public.driver_ui_flags;
create policy "driver_ui_flags_select_own"
  on public.driver_ui_flags
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "driver_ui_flags_insert_own" on public.driver_ui_flags;
create policy "driver_ui_flags_insert_own"
  on public.driver_ui_flags
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "driver_ui_flags_update_own" on public.driver_ui_flags;
create policy "driver_ui_flags_update_own"
  on public.driver_ui_flags
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "driver_ui_flags_service_role_all" on public.driver_ui_flags;
create policy "driver_ui_flags_service_role_all"
  on public.driver_ui_flags
  for all
  to service_role
  using (true)
  with check (true);

create or replace function public.set_driver_ui_flags_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_driver_ui_flags_updated_at on public.driver_ui_flags;
create trigger trg_driver_ui_flags_updated_at
before update on public.driver_ui_flags
for each row execute function public.set_driver_ui_flags_updated_at();
