# Supabase migrations (HeyCaby)

Apply with the [Supabase CLI](https://supabase.com/docs/guides/cli) linked to project `fvrprxguoternoxnyhoj`, or paste SQL into **Dashboard → SQL Editor**.

## Environment-specific webhook config

Do **not** promote staging-only webhook URL migrations to production.

Production must use `migrations/20260701144500_driver_agent_webhook_url_config.sql`, which sets `app_config.agent_webhook_url` to:

`https://fvrprxguoternoxnyhoj.supabase.co/functions/v1/driver-agent`

Staging/branches may have remote migration history names such as `driver_agent_webhook_url_config_staging`. Those are environment-specific history entries and must stay out of production. If staging needs a different URL, update only staging `app_config.agent_webhook_url` or apply a staging-only migration in the staging project.

| File | Purpose |
|------|---------|
| `migrations/20260403193000_rider_identity_booking_prefs.sql` | Adds **`rider_identities.preferred_payment_methods`**, **`preferred_vehicle_category`**, **`preferred_pet_friendly`** — required for rider default booking prefs sync; apply before device/App Store testing or the app falls back to local-only prefs for those fields. |
| `migrations/20260408120000_invite_short_codes.sql` | **`invite_codes`** table (7-char `[a-zA-Z0-9]` codes), **`fn_ensure_rider_invite_code`**, **`fn_ensure_driver_invite_code`**, **`fn_lookup_invite_code`** — used for **web / deep-link** flows and analytics; Rider & Driver **TAF share/copy in the apps** intentionally use the plain homepage only (`kAppPublicSiteRoot` from `APP_PUBLIC_WEB_ORIGIN`, no `/invite` or query). |
| `migrations/20260320120000_fn_admin_set_manual_verifications.sql` | RPC for admins to set `chauffeurspas_verified`, `kvk_verified`, and final `profile_status` / `compliance_status` on **`drivers`** (no new tables). |
| `functions/apple-review-auth/index.ts` | App Store review login: validates `app_config` (`apple_review_enabled`, `apple_review_email`, `apple_review_otp`), ensures Auth user + compliant **`drivers`** row via `setup_review_driver_profile`, returns session tokens. Deploy with Supabase CLI or Dashboard. Disable after approval: `UPDATE app_config SET value = 'false' WHERE key = 'apple_review_enabled';` |
| `functions/driver-support-chat/index.ts` | AI driver support (Lee): JWT → `tickets` for `user_type=driver`, **OpenRouter** chat completions. Secrets: `OPENROUTER_API_KEY`, optional `SUPPORT_AI_MODEL` (default `openrouter/free`), optional `OPENROUTER_SITE_URL` / `OPENROUTER_APP_TITLE`. |
| `functions/rider-support-chat/index.ts` | Same for riders (`user_type=rider`). Flutter invokes `rider-support-chat` with JWT only. |
See **`docs/DRIVER_VERIFICATION_IMPLEMENTATION.md`** in the repo root for Flutter wiring and admin workflow.
