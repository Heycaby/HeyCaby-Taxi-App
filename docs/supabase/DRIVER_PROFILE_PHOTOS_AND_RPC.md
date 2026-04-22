# Driver profile — public photos + RPCs (migration 043+)

## Storage

- **Profile photos** must use the **`driver-photos`** bucket (public). The app uploads to this bucket and stores `getPublicUrl` in `drivers.profile_photo_url`.
- **`driver-documents`** stays **private** (compliance uploads, insurance, etc.). Using `.../object/public/driver-documents/...` returns **403** for clients — do not use it for avatars.

## RPCs (Flutter integration)

| RPC | Params | Purpose |
|-----|--------|---------|
| `get_or_create_driver` | `p_user_id` (uuid) | Idempotent: ensures `drivers` (+ onboarding rows per your migration). |
| `save_driver_profile` | `p_user_id`, optional `p_full_name`, `p_profile_photo_url` | Centralized updates; can enforce `profile_photo_locked`. |

The driver app calls `bootstrapDriverRow()` on **splash continue** and once when **`DriverShell`** mounts, then invalidates `driverIdProvider` and `driverProfileProvider`.

## One-time fix for a broken legacy URL

If a driver locked a photo that pointed at the private bucket, unlock + clear in SQL (Dashboard), then they re-upload:

```sql
UPDATE drivers SET
  profile_photo_locked = false,
  profile_photo_locked_at = NULL,
  profile_photo_url = NULL
WHERE user_id = '<auth_user_uuid>';
```

## Fallback behaviour

If `get_or_create_driver` / `save_driver_profile` are missing (older DB), the app falls back to direct `drivers` inserts/updates so development is not blocked.
