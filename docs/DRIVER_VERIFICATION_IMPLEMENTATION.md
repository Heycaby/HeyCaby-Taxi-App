# Driver verification (admin + Flutter) — implementation

Uses **existing** `public.drivers` columns (no new tables). Aligned with `heycaby_flutter_spec.md`:

| Column | Purpose |
|--------|---------|
| `profile_status` | `incomplete` → `pending_review` → **`verified`** / `suspended` |
| `compliance_status` | `pending` / `pending_review` → **`compliant`** when all checks pass |
| `chauffeurspas_verified` | Manual (Kiwa) — admin sets `true` after hand check |
| `kvk_verified` | Manual (KVK website) — admin sets `true` |
| `rijbewijs_verified` / Veriff | Automatic (webhook + app) |
| `vehicle_verified`, `vehicle_verification_status`, `taxi_insurance_verified, …` | Automatic / existing flows |
| `congratulations_modal_shown` | After `p_mark_fully_verified`, set `false` so the app shows congrats |

## 1. Supabase migration

Run:

`supabase/migrations/20260320120000_fn_admin_set_manual_verifications.sql`

Function: **`fn_admin_set_manual_verifications(p_driver_id, p_chauffeurspas_verified, p_kvk_verified, p_mark_fully_verified)`**

- Caller must be **`auth.users`** with **`raw_app_meta_data.role`** in **`admin`** or **`super_admin`** (set in Dashboard → Authentication → Users → user → Edit → App metadata → `{"role":"admin"}`).

### Example (SQL Editor)

```sql
-- Approve manual checks only
select fn_admin_set_manual_verifications(
  'DRIVER_UUID_HERE'::uuid,
  p_chauffeurspas_verified := true,
  p_kvk_verified := true,
  p_mark_fully_verified := false
);

-- When everything else (Veriff, RDW, insurance) is already OK — final approve
select fn_admin_set_manual_verifications(
  'DRIVER_UUID_HERE'::uuid,
  p_chauffeurspas_verified := true,
  p_kvk_verified := true,
  p_mark_fully_verified := true
);
```

**Note:** If your database already has a **trigger** that computes `compliance_status` from individual flags, adjust the RPC or call `p_mark_fully_verified := false` and only flip flags; then let the trigger set `compliant`. If there is **no** trigger, the RPC sets `compliance_status = 'compliant'` and `profile_status = 'verified'` when `p_mark_fully_verified` is true.

## 2. Flutter app (this repo)

- **Go online** is blocked unless `compliance_status == 'compliant'` (`driver_swipe_to_go_online.dart`).
- **Congratulations** modal when `profile_status == 'verified'` and `congratulations_modal_shown` is false (`driver_home_screen.dart`).
- **Realtime** on `drivers` invalidates profile + compliance when admin updates the row (`driver_profile_realtime_listener.dart` in shell).
- **Banner** when `profile_status == 'pending_review'` (`driver_verification_status_banner.dart`).

## 3. `/admin` UI (HeyCaby web or internal tool)

Not in this repo. Options:

- Call **RPC** from a **server route** with service role (preferred for production), or
- **Supabase Studio** (Table Editor / SQL) for v1.

## 4. Future

- Optional `driver_verifications` table (already in product spec) for per-document audit history.
- Push notification Edge Function on `p_mark_fully_verified`.
