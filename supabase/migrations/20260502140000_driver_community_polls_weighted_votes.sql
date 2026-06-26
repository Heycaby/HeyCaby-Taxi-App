-- Driver community polls with weighted votes (founding drivers count triple).
-- Posts use content prefix '[poll]' with poll metadata in community_polls / options / votes.

begin;

create table if not exists public.community_polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  question text not null,
  created_at timestamptz not null default now(),
  constraint community_polls_question_len check (char_length(trim(question)) between 3 and 500),
  constraint community_polls_post_unique unique (post_id)
);

create table if not exists public.community_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.community_polls(id) on delete cascade,
  label text not null,
  position int not null,
  constraint community_poll_options_label_len check (char_length(trim(label)) between 1 and 200),
  constraint community_poll_options_poll_pos unique (poll_id, position)
);

create index if not exists idx_community_poll_options_poll
  on public.community_poll_options(poll_id);

create table if not exists public.community_poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.community_polls(id) on delete cascade,
  option_id uuid not null references public.community_poll_options(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  vote_weight numeric not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_poll_votes_poll_driver unique (poll_id, driver_id)
);

create index if not exists idx_community_poll_votes_poll
  on public.community_poll_votes(poll_id);

-- Server-side weight: founding drivers get 3 points, everyone else 1.
create or replace function public.fn_community_poll_vote_apply_weight()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_founding boolean;
begin
  select coalesce(d.is_founding_driver, false)
    into v_founding
  from public.drivers d
  where d.id = new.driver_id;

  new.vote_weight := case when v_founding then 3 else 1 end;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_community_poll_vote_weight on public.community_poll_votes;
create trigger trg_community_poll_vote_weight
  before insert or update of option_id, driver_id on public.community_poll_votes
  for each row
  execute function public.fn_community_poll_vote_apply_weight();

alter table public.community_polls enable row level security;
alter table public.community_poll_options enable row level security;
alter table public.community_poll_votes enable row level security;

drop policy if exists "community_polls_select_auth" on public.community_polls;
create policy "community_polls_select_auth"
  on public.community_polls for select to authenticated using (true);

drop policy if exists "community_poll_options_select_auth" on public.community_poll_options;
create policy "community_poll_options_select_auth"
  on public.community_poll_options for select to authenticated using (true);

drop policy if exists "community_poll_votes_select_auth" on public.community_poll_votes;
create policy "community_poll_votes_select_auth"
  on public.community_poll_votes for select to authenticated using (true);

drop policy if exists "community_poll_votes_insert_own" on public.community_poll_votes;
create policy "community_poll_votes_insert_own"
  on public.community_poll_votes for insert to authenticated
  with check (
    exists (
      select 1 from public.drivers d
      where d.id = driver_id and d.user_id = auth.uid()
    )
  );

drop policy if exists "community_poll_votes_update_own" on public.community_poll_votes;
create policy "community_poll_votes_update_own"
  on public.community_poll_votes for update to authenticated
  using (
    exists (
      select 1 from public.drivers d
      where d.id = driver_id and d.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.drivers d
      where d.id = driver_id and d.user_id = auth.uid()
    )
  );

-- Create a driver poll post + options (counts toward community post rate limits).
create or replace function public.create_community_poll(p_question text, p_options text[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver_id uuid;
  v_post_id uuid;
  v_poll_id uuid;
  v_opt text;
  v_i int := 0;
  v_n int;
begin
  if p_options is null then
    raise exception 'invalid_options' using errcode = 'P0001';
  end if;

  select coalesce(array_length(p_options, 1), 0) into v_n;
  if v_n < 2 or v_n > 6 then
    raise exception 'invalid_options_count' using errcode = 'P0001';
  end if;

  select id into v_driver_id from public.drivers where user_id = auth.uid();
  if v_driver_id is null then
    raise exception 'not_driver' using errcode = 'P0001';
  end if;

  if char_length(trim(p_question)) < 3 then
    raise exception 'question_too_short' using errcode = 'P0001';
  end if;

  insert into public.community_posts (driver_id, channel, content)
  values (v_driver_id, 'general', '[poll]')
  returning id into v_post_id;

  insert into public.community_polls (post_id, question)
  values (v_post_id, trim(p_question))
  returning id into v_poll_id;

  foreach v_opt in array p_options loop
    v_i := v_i + 1;
    if char_length(trim(v_opt)) < 1 then
      raise exception 'empty_option' using errcode = 'P0001';
    end if;
    insert into public.community_poll_options (poll_id, label, position)
    values (v_poll_id, trim(v_opt), v_i);
  end loop;

  return v_post_id;
end;
$$;

grant execute on function public.create_community_poll(text, text[]) to authenticated;

commit;
