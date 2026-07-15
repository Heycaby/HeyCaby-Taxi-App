begin;

do $$
declare
  broad_saved_trip_policies integer;
  storage_listing_policies integer;
  mutable_search_paths integer;
begin
  select count(*) into broad_saved_trip_policies
  from pg_policies
  where schemaname = 'public'
    and tablename = 'saved_trips'
    and roles @> array['public']::name[];

  if broad_saved_trip_policies <> 0 then
    raise exception 'saved_trips still has % PUBLIC policies', broad_saved_trip_policies;
  end if;

  if has_table_privilege('anon', 'public.app_analytics', 'INSERT')
     or has_table_privilege('authenticated', 'public.app_analytics', 'INSERT') then
    raise exception 'direct client analytics INSERT remains granted';
  end if;

  select count(*) into storage_listing_policies
  from pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
    and policyname in (
      'driver_photos_public_read',
      'public_read_driver_photos',
      'public_read_taxii_profiles'
    );

  if storage_listing_policies <> 0 then
    raise exception 'public storage listing policies remain';
  end if;

  select count(*) into mutable_search_paths
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'fn_billing_derive_status',
      'fn_connectivity_operational_target',
      'fn_connectivity_transport_target',
      'fn_driver_readiness_checklist_v2',
      'fn_driver_shift_handover_grace_seconds',
      'fn_taxi_terug_empty_km_for_ride',
      'fn_taxi_terug_fare_euros',
      'fn_taxi_terug_match_score',
      'set_driver_app_suggestions_updated_at',
      'set_driver_ui_flags_updated_at',
      'set_zone_smart_targets_updated_at',
      'trg_ride_requests_capture_booked_destination',
      'update_driver_email_events_updated_at',
      'update_waitlist_updated_at'
    )
    and not coalesce(p.proconfig, array[]::text[]) @> array['search_path=public, pg_temp'];

  if mutable_search_paths <> 0 then
    raise exception '% audited functions still lack a fixed search_path', mutable_search_paths;
  end if;

  raise notice 'advisor_authority_hardening_passed';
end
$$;

rollback;
