-- Production migration 20260713135507.
-- Domain authority hardening: remove remaining broad client access that can be
-- closed without changing supported product behavior.

-- Saved trips belong to the authenticated rider identity. The former public
-- policies exposed every saved route and allowed cross-rider mutation.
drop policy if exists riders_select_saved_trips on public.saved_trips;
drop policy if exists riders_insert_saved_trips on public.saved_trips;
drop policy if exists riders_update_saved_trips on public.saved_trips;
drop policy if exists riders_delete_saved_trips on public.saved_trips;
drop policy if exists service_role_manage_saved_trips on public.saved_trips;

create policy riders_select_own_saved_trips
on public.saved_trips
for select
to authenticated
using (
  exists (
    select 1
    from public.rider_identities ri
    where ri.id = saved_trips.rider_identity_id
      and ri.user_id = (select auth.uid())
  )
);

create policy riders_insert_own_saved_trips
on public.saved_trips
for insert
to authenticated
with check (
  exists (
    select 1
    from public.rider_identities ri
    where ri.id = saved_trips.rider_identity_id
      and ri.user_id = (select auth.uid())
  )
);

create policy riders_update_own_saved_trips
on public.saved_trips
for update
to authenticated
using (
  exists (
    select 1
    from public.rider_identities ri
    where ri.id = saved_trips.rider_identity_id
      and ri.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.rider_identities ri
    where ri.id = saved_trips.rider_identity_id
      and ri.user_id = (select auth.uid())
  )
);

create policy riders_delete_own_saved_trips
on public.saved_trips
for delete
to authenticated
using (
  exists (
    select 1
    from public.rider_identities ri
    where ri.id = saved_trips.rider_identity_id
      and ri.user_id = (select auth.uid())
  )
);

create policy service_role_manage_saved_trips
on public.saved_trips
for all
to service_role
using (true)
with check (true);

-- Analytics is accepted and validated by track-analytics, which writes with
-- service-role authority. Direct arbitrary table inserts are not a public API.
drop policy if exists "Anyone can log analytics" on public.app_analytics;
revoke insert on public.app_analytics from anon, authenticated;

-- Public buckets already serve public object URLs without a SELECT policy.
-- Removing these policies prevents anonymous bucket enumeration.
drop policy if exists driver_photos_public_read on storage.objects;
drop policy if exists public_read_driver_photos on storage.objects;
drop policy if exists public_read_taxii_profiles on storage.objects;

-- Pin search paths so caller-controlled schemas cannot shadow referenced names.
alter function public.fn_billing_derive_status(bigint, bigint)
  set search_path = public, pg_temp;
alter function public.fn_connectivity_operational_target(text, text)
  set search_path = public, pg_temp;
alter function public.fn_connectivity_transport_target(text, text)
  set search_path = public, pg_temp;
alter function public.fn_driver_readiness_checklist_v2(public.drivers, boolean, integer, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)
  set search_path = public, pg_temp;
alter function public.fn_driver_shift_handover_grace_seconds(text)
  set search_path = public, pg_temp;
alter function public.fn_taxi_terug_empty_km_for_ride(public.ride_requests)
  set search_path = public, pg_temp;
alter function public.fn_taxi_terug_fare_euros(public.ride_requests)
  set search_path = public, pg_temp;
alter function public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric)
  set search_path = public, pg_temp;
alter function public.fn_taxi_terug_match_score(numeric, numeric, numeric, numeric, numeric, numeric, numeric)
  set search_path = public, pg_temp;
alter function public.set_driver_app_suggestions_updated_at()
  set search_path = public, pg_temp;
alter function public.set_driver_ui_flags_updated_at()
  set search_path = public, pg_temp;
alter function public.set_zone_smart_targets_updated_at()
  set search_path = public, pg_temp;
alter function public.trg_ride_requests_capture_booked_destination()
  set search_path = public, pg_temp;
alter function public.update_driver_email_events_updated_at()
  set search_path = public, pg_temp;
alter function public.update_waitlist_updated_at()
  set search_path = public, pg_temp;
