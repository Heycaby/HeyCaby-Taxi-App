-- Device permission snapshot for rider app (OS grants, synced from the client).
ALTER TABLE public.rider_identities
  ADD COLUMN IF NOT EXISTS app_location_permission_granted boolean,
  ADD COLUMN IF NOT EXISTS app_notification_permission_granted boolean,
  ADD COLUMN IF NOT EXISTS app_permissions_synced_at timestamptz;

COMMENT ON COLUMN public.rider_identities.app_location_permission_granted IS
  'Last known OS location permission (when-in-use or better) from rider app.';
COMMENT ON COLUMN public.rider_identities.app_notification_permission_granted IS
  'Last known OS notification permission (including iOS provisional) from rider app.';
COMMENT ON COLUMN public.rider_identities.app_permissions_synced_at IS
  'When the rider app last reported permission flags.';
