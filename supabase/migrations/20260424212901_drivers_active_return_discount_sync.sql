-- Mirror active rate profile return discount onto drivers so riders can read it
-- under existing drivers_select RLS (driver_rate_profiles is driver-only).

alter table public.drivers
  add column if not exists active_return_discount_pct numeric;

update public.drivers
set active_return_discount_pct = 0
where active_return_discount_pct is null;

alter table public.drivers
  alter column active_return_discount_pct set default 0;

alter table public.drivers
  alter column active_return_discount_pct set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'drivers_active_return_discount_pct_check'
  ) then
    alter table public.drivers
      add constraint drivers_active_return_discount_pct_check
      check (active_return_discount_pct >= 0 and active_return_discount_pct <= 40);
  end if;
end $$;

create or replace function public.fn_sync_driver_active_return_discount()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid;
  v_pct numeric;
begin
  v_driver := coalesce(new.driver_id, old.driver_id);
  if v_driver is null then
    return coalesce(new, old);
  end if;

  select coalesce(p.return_discount_pct, 0) into v_pct
  from public.driver_rate_profiles p
  where p.driver_id = v_driver and p.is_active is true
  order by p.updated_at desc nulls last
  limit 1;

  update public.drivers d
  set active_return_discount_pct = coalesce(v_pct, 0)
  where d.id = v_driver;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_driver_rate_profiles_sync_active_discount on public.driver_rate_profiles;
create trigger trg_driver_rate_profiles_sync_active_discount
after insert or delete or update of return_discount_pct, is_active
on public.driver_rate_profiles
for each row execute function public.fn_sync_driver_active_return_discount();

update public.drivers d
set active_return_discount_pct = coalesce((
  select p.return_discount_pct
  from public.driver_rate_profiles p
  where p.driver_id = d.id and p.is_active is true
  order by p.updated_at desc nulls last
  limit 1
), 0);
