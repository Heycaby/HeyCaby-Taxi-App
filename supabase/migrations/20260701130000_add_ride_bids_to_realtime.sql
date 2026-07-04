-- Marketplace offers are delivered to riders through Realtime subscriptions on
-- public.ride_bids. Keep this idempotent so older branches/environments can
-- apply it safely after the publication already contains the table.
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and to_regclass('public.ride_bids') is not null
    and not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'ride_bids'
    )
  then
    alter publication supabase_realtime add table public.ride_bids;
  end if;
end $$;
