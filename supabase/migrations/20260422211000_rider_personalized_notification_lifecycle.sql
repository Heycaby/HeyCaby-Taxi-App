-- Personalized rider lifecycle notifications (campaigns + events + scheduled jobs)

create table if not exists public.rider_notification_profiles (
  rider_identity_id uuid primary key references public.rider_identities(id) on delete cascade,
  timezone text not null default 'Europe/Amsterdam',
  notifications_enabled boolean not null default true,
  quiet_hours_start time not null default time '22:00',
  quiet_hours_end time not null default time '08:00',
  first_seen_at timestamptz,
  first_ride_completed_at timestamptz,
  last_app_open_at timestamptz,
  last_ride_completed_at timestamptz,
  welcome_sent_at timestamptz,
  first_ride_nudge_sent_at timestamptz,
  share_nudge_sent_at timestamptz,
  inactive_3d_sent_at timestamptz,
  inactive_7d_sent_at timestamptz,
  inactive_14d_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_campaigns (
  id uuid primary key default gen_random_uuid(),
  campaign_key text not null unique,
  title_template text not null,
  body_template text not null,
  channel text not null default 'both' check (channel in ('push', 'in_app', 'both', 'silent')),
  priority text not null default 'medium' check (priority in ('critical', 'high', 'medium', 'low', 'silent')),
  cooldown_hours integer not null default 24,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  rider_identity_id uuid not null references public.rider_identities(id) on delete cascade,
  event_key text not null,
  event_payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists notification_lifecycle_events_rider_time_idx
  on public.notification_lifecycle_events(rider_identity_id, occurred_at desc);

create table if not exists public.notification_lifecycle_jobs (
  id uuid primary key default gen_random_uuid(),
  rider_identity_id uuid not null references public.rider_identities(id) on delete cascade,
  campaign_key text not null references public.notification_campaigns(campaign_key) on delete cascade,
  trigger_event_id uuid references public.notification_lifecycle_events(id) on delete set null,
  scheduled_for timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  attempts integer not null default 0,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists notification_lifecycle_jobs_event_campaign_uniq
  on public.notification_lifecycle_jobs(trigger_event_id, campaign_key)
  where trigger_event_id is not null;

create index if not exists notification_lifecycle_jobs_due_idx
  on public.notification_lifecycle_jobs(status, scheduled_for);

alter table public.rider_notification_profiles enable row level security;
alter table public.notification_campaigns enable row level security;
alter table public.notification_lifecycle_events enable row level security;
alter table public.notification_lifecycle_jobs enable row level security;

drop policy if exists rider_notification_profiles_select_owner on public.rider_notification_profiles;
create policy rider_notification_profiles_select_owner
on public.rider_notification_profiles
for select to authenticated
using (
  exists (
    select 1 from public.rider_identities ri
    where ri.id = rider_identity_id and ri.user_id = auth.uid()
  )
);

drop policy if exists rider_notification_profiles_update_owner on public.rider_notification_profiles;
create policy rider_notification_profiles_update_owner
on public.rider_notification_profiles
for update to authenticated
using (
  exists (
    select 1 from public.rider_identities ri
    where ri.id = rider_identity_id and ri.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.rider_identities ri
    where ri.id = rider_identity_id and ri.user_id = auth.uid()
  )
);

drop policy if exists notification_campaigns_no_client_access on public.notification_campaigns;
create policy notification_campaigns_no_client_access
on public.notification_campaigns
for all to authenticated
using (false)
with check (false);

drop policy if exists notification_lifecycle_events_select_owner on public.notification_lifecycle_events;
create policy notification_lifecycle_events_select_owner
on public.notification_lifecycle_events
for select to authenticated
using (
  exists (
    select 1 from public.rider_identities ri
    where ri.id = rider_identity_id and ri.user_id = auth.uid()
  )
);

drop policy if exists notification_lifecycle_events_no_direct_insert on public.notification_lifecycle_events;
create policy notification_lifecycle_events_no_direct_insert
on public.notification_lifecycle_events
for insert to authenticated
with check (false);

drop policy if exists notification_lifecycle_jobs_select_owner on public.notification_lifecycle_jobs;
create policy notification_lifecycle_jobs_select_owner
on public.notification_lifecycle_jobs
for select to authenticated
using (
  exists (
    select 1 from public.rider_identities ri
    where ri.id = rider_identity_id and ri.user_id = auth.uid()
  )
);

drop policy if exists notification_lifecycle_jobs_no_client_mutation on public.notification_lifecycle_jobs;
create policy notification_lifecycle_jobs_no_client_mutation
on public.notification_lifecycle_jobs
for all to authenticated
using (false)
with check (false);

insert into public.notification_campaigns (campaign_key, title_template, body_template, channel, priority, cooldown_hours, enabled)
values
  ('welcome_signup', 'Welcome to HeyCaby', 'We''re excited to have you. Need anything? We''re one tap away.', 'both', 'medium', 168, true),
  ('first_ride_nudge', 'How was your first ride?', 'Thanks for riding with us. Ready for your next trip?', 'both', 'medium', 72, true),
  ('share_early', 'Invite friends to HeyCaby', 'Share HeyCaby with friends and help your city ride smarter.', 'both', 'low', 168, true),
  ('inactive_3d', 'Need a ride today?', 'We''re here when you need a smooth, reliable trip.', 'both', 'low', 72, true),
  ('inactive_7d', 'Remember, we''re here when others aren''t', 'Day or night, HeyCaby is ready when you are.', 'both', 'medium', 168, true),
  ('inactive_14d', 'We miss you at HeyCaby', 'Come back anytime - your next ride is waiting.', 'both', 'medium', 336, true),
  ('scheduled_3d', 'Your trip is coming up', 'Reminder: your scheduled ride is in 3 days.', 'both', 'high', 48, true)
on conflict (campaign_key) do update
set
  title_template = excluded.title_template,
  body_template = excluded.body_template,
  channel = excluded.channel,
  priority = excluded.priority,
  cooldown_hours = excluded.cooldown_hours,
  enabled = excluded.enabled,
  updated_at = now();

create or replace function public.fn_track_rider_lifecycle_event(
  p_event_key text,
  p_event_payload jsonb default '{}'::jsonb,
  p_rider_identity_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_rider_identity_id uuid;
  v_now timestamptz := now();
  v_event_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not_authenticated');
  end if;

  if p_event_key is null or length(trim(p_event_key)) = 0 then
    return jsonb_build_object('success', false, 'error', 'invalid_event_key');
  end if;

  if p_rider_identity_id is not null then
    if not exists (
      select 1 from public.rider_identities ri
      where ri.id = p_rider_identity_id and ri.user_id = v_uid
    ) then
      return jsonb_build_object('success', false, 'error', 'identity_mismatch');
    end if;
    v_rider_identity_id := p_rider_identity_id;
  else
    select ri.id into v_rider_identity_id
    from public.rider_identities ri
    where ri.user_id = v_uid
    order by ri.created_at desc
    limit 1;
    if v_rider_identity_id is null then
      return jsonb_build_object('success', false, 'error', 'identity_not_found');
    end if;
  end if;

  insert into public.rider_notification_profiles (rider_identity_id, first_seen_at, updated_at)
  values (v_rider_identity_id, v_now, v_now)
  on conflict (rider_identity_id) do update
    set updated_at = v_now;

  if p_event_key = 'app_open' then
    update public.rider_notification_profiles
    set
      first_seen_at = coalesce(first_seen_at, v_now),
      last_app_open_at = v_now,
      updated_at = v_now
    where rider_identity_id = v_rider_identity_id;
  elsif p_event_key = 'ride_completed' then
    update public.rider_notification_profiles
    set
      first_ride_completed_at = coalesce(first_ride_completed_at, v_now),
      last_ride_completed_at = v_now,
      updated_at = v_now
    where rider_identity_id = v_rider_identity_id;
  end if;

  insert into public.notification_lifecycle_events (
    rider_identity_id,
    event_key,
    event_payload,
    occurred_at
  )
  values (
    v_rider_identity_id,
    trim(p_event_key),
    coalesce(p_event_payload, '{}'::jsonb),
    v_now
  )
  returning id into v_event_id;

  return jsonb_build_object(
    'success', true,
    'event_id', v_event_id,
    'rider_identity_id', v_rider_identity_id
  );
end;
$$;

revoke all on function public.fn_track_rider_lifecycle_event(text, jsonb, uuid) from public;
grant execute on function public.fn_track_rider_lifecycle_event(text, jsonb, uuid) to authenticated;

create or replace function public.fn_plan_rider_lifecycle_jobs()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_pickup_at timestamptz;
  v_three_day_at timestamptz;
begin
  if new.event_key in ('app_open', 'ride_completed', 'booking_created') then
    update public.notification_lifecycle_jobs
      set status = 'cancelled', updated_at = now()
    where rider_identity_id = new.rider_identity_id
      and status = 'pending'
      and campaign_key in ('inactive_3d', 'inactive_7d', 'inactive_14d');

    insert into public.notification_lifecycle_jobs (
      rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
    )
    select new.rider_identity_id, c.campaign_key, new.id, new.occurred_at + interval '3 days',
           c.title_template, c.body_template, jsonb_build_object('campaign', c.campaign_key, 'event_key', new.event_key)
    from public.notification_campaigns c
    where c.enabled = true and c.campaign_key = 'inactive_3d'
    on conflict do nothing;

    insert into public.notification_lifecycle_jobs (
      rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
    )
    select new.rider_identity_id, c.campaign_key, new.id, new.occurred_at + interval '7 days',
           c.title_template, c.body_template, jsonb_build_object('campaign', c.campaign_key, 'event_key', new.event_key)
    from public.notification_campaigns c
    where c.enabled = true and c.campaign_key = 'inactive_7d'
    on conflict do nothing;

    insert into public.notification_lifecycle_jobs (
      rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
    )
    select new.rider_identity_id, c.campaign_key, new.id, new.occurred_at + interval '14 days',
           c.title_template, c.body_template, jsonb_build_object('campaign', c.campaign_key, 'event_key', new.event_key)
    from public.notification_campaigns c
    where c.enabled = true and c.campaign_key = 'inactive_14d'
    on conflict do nothing;
  end if;

  if new.event_key = 'signup_completed' then
    insert into public.notification_lifecycle_jobs (
      rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
    )
    select new.rider_identity_id, c.campaign_key, new.id, new.occurred_at + interval '5 minutes',
           c.title_template, c.body_template, jsonb_build_object('campaign', c.campaign_key)
    from public.notification_campaigns c
    where c.enabled = true and c.campaign_key = 'welcome_signup'
    on conflict do nothing;
  end if;

  if new.event_key = 'ride_completed'
     and exists (
       select 1
       from public.rider_notification_profiles p
       where p.rider_identity_id = new.rider_identity_id
         and p.first_ride_completed_at = new.occurred_at
     ) then
    insert into public.notification_lifecycle_jobs (
      rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
    )
    select new.rider_identity_id, c.campaign_key, new.id, new.occurred_at + interval '4 hours',
           c.title_template, c.body_template, jsonb_build_object('campaign', c.campaign_key)
    from public.notification_campaigns c
    where c.enabled = true and c.campaign_key = 'first_ride_nudge'
    on conflict do nothing;

    insert into public.notification_lifecycle_jobs (
      rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
    )
    select new.rider_identity_id, c.campaign_key, new.id, new.occurred_at + interval '36 hours',
           c.title_template, c.body_template, jsonb_build_object('campaign', c.campaign_key)
    from public.notification_campaigns c
    where c.enabled = true and c.campaign_key = 'share_early'
    on conflict do nothing;
  end if;

  if new.event_key = 'scheduled_ride_created' then
    begin
      v_pickup_at := (new.event_payload->>'scheduled_pickup_at')::timestamptz;
    exception when others then
      v_pickup_at := null;
    end;

    if v_pickup_at is not null then
      v_three_day_at := v_pickup_at - interval '3 days';
      if v_three_day_at > now() then
        insert into public.notification_lifecycle_jobs (
          rider_identity_id, campaign_key, trigger_event_id, scheduled_for, title, body, data
        )
        select new.rider_identity_id, c.campaign_key, new.id, v_three_day_at,
               c.title_template, c.body_template, jsonb_build_object(
                 'campaign', c.campaign_key,
                 'scheduled_pickup_at', new.event_payload->>'scheduled_pickup_at'
               )
        from public.notification_campaigns c
        where c.enabled = true and c.campaign_key = 'scheduled_3d'
        on conflict do nothing;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_plan_rider_lifecycle_jobs on public.notification_lifecycle_events;
create trigger trg_plan_rider_lifecycle_jobs
after insert on public.notification_lifecycle_events
for each row execute function public.fn_plan_rider_lifecycle_jobs();

create or replace function public.fn_claim_due_rider_lifecycle_jobs(p_limit integer default 50)
returns setof public.notification_lifecycle_jobs
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with claimed as (
    update public.notification_lifecycle_jobs j
      set status = 'processing',
          attempts = j.attempts + 1,
          updated_at = now()
    where j.id in (
      select id
      from public.notification_lifecycle_jobs
      where status = 'pending'
        and scheduled_for <= now()
      order by scheduled_for asc
      for update skip locked
      limit greatest(coalesce(p_limit, 50), 1)
    )
    returning j.*
  )
  select * from claimed;
end;
$$;

revoke all on function public.fn_claim_due_rider_lifecycle_jobs(integer) from public;
grant execute on function public.fn_claim_due_rider_lifecycle_jobs(integer) to authenticated;
