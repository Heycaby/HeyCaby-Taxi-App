-- Driver profile upgrades:
-- 1) Profile photo can be changed up to 2 times in-app.
-- 2) Driver can upload up to 2 rider-visible vehicle photos.

alter table public.drivers
  add column if not exists profile_photo_change_count integer not null default 0;

alter table public.drivers
  add column if not exists vehicle_photo_urls text[] not null default '{}';

-- Backfill count for existing profiles with a photo.
update public.drivers
set profile_photo_change_count = 1
where coalesce(profile_photo_change_count, 0) = 0
  and coalesce(nullif(trim(profile_photo_url), ''), '') <> '';

-- New product rule: lock only after 2 in-app changes.
update public.drivers
set profile_photo_locked = (coalesce(profile_photo_change_count, 0) >= 2);
