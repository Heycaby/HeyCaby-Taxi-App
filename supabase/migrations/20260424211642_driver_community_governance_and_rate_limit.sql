-- Driver community governance:
-- - 24h retention window
-- - strict post rate limit
-- - edit/delete own posts
-- - reactions (like/thanks)
-- - first-open community consent flags

alter table if exists public.driver_ui_flags
  add column if not exists community_disclaimer_accepted boolean not null default false,
  add column if not exists community_disclaimer_accepted_at timestamptz;

create table if not exists public.community_post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  reaction_type text not null check (reaction_type in ('like', 'thanks')),
  created_at timestamptz not null default now(),
  unique (post_id, driver_id, reaction_type)
);

create index if not exists idx_community_post_reactions_post
  on public.community_post_reactions(post_id);
create index if not exists idx_community_post_reactions_driver
  on public.community_post_reactions(driver_id);

alter table public.community_post_reactions enable row level security;

drop policy if exists "community_reactions_select_all_auth" on public.community_post_reactions;
create policy "community_reactions_select_all_auth"
  on public.community_post_reactions
  for select
  to authenticated
  using (true);

drop policy if exists "community_reactions_insert_own_driver" on public.community_post_reactions;
create policy "community_reactions_insert_own_driver"
  on public.community_post_reactions
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.drivers d
      where d.id = driver_id and d.user_id = auth.uid()
    )
  );

drop policy if exists "community_reactions_delete_own_driver" on public.community_post_reactions;
create policy "community_reactions_delete_own_driver"
  on public.community_post_reactions
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.drivers d
      where d.id = driver_id and d.user_id = auth.uid()
    )
  );

drop policy if exists "community_posts_update_own_driver" on public.community_posts;
create policy "community_posts_update_own_driver"
  on public.community_posts
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.drivers d
      where d.id = community_posts.driver_id and d.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.drivers d
      where d.id = community_posts.driver_id and d.user_id = auth.uid()
    )
  );

drop policy if exists "community_posts_delete_own_driver" on public.community_posts;
create policy "community_posts_delete_own_driver"
  on public.community_posts
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.drivers d
      where d.id = community_posts.driver_id and d.user_id = auth.uid()
    )
  );

create or replace function public.fn_community_cleanup_expired_posts()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.community_posts
  where created_at < now() - interval '24 hours';
$$;

create or replace function public.fn_community_enforce_post_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count int;
begin
  if new.channel = 'announcements' then
    -- Announcement publishing is admin-only in practice.
    return new;
  end if;

  select count(*)
    into recent_count
  from public.community_posts
  where driver_id = new.driver_id
    and created_at >= now() - interval '1 minute';

  -- Strict anti-spam: max 3 posts / minute / driver.
  if recent_count >= 3 then
    raise exception using
      errcode = 'P0001',
      message = 'community_rate_limit_exceeded';
  end if;

  perform public.fn_community_cleanup_expired_posts();
  return new;
end;
$$;

drop trigger if exists trg_community_post_rules on public.community_posts;
create trigger trg_community_post_rules
before insert on public.community_posts
for each row execute function public.fn_community_enforce_post_rules();
