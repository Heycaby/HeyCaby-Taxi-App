# Clean slate: remove all drivers (demo / test data)

Use this when you want **zero driver rows** in Supabase so you can onboard again as the first real driver.

> **Warning:** This deletes **all** rows in `public.drivers` and related driver data, then removes the matching **Auth** users. Back up your project (or run on a dev branch) if you are unsure.

## What you need

- Supabase project: **Dashboard → SQL Editor**
- Prefer running as a user with rights to `auth` schema (usually the **postgres** role / service role in SQL Editor)

## Steps

1. **Optional backup:** Dashboard → Database → Backups (or export).
2. Run the script via **Supabase MCP** (`execute_sql` on your project) or paste into **SQL Editor**. Repo file: **`../../supabase/scripts/wipe_all_driver_data.sql`** (matches HeyCaby production Supabase schema: `ride_ratings` not the view, `tickets.user_id` as text, no `driver_return_trips` / `driver_market_signals` deletes).
3. Read the comments at the top (especially **ride history** vs **nulling `driver_id`**).
4. Paste into SQL Editor and run **once**.
5. **Storage (optional):** Dashboard → Storage → bucket `driver-documents` → delete old objects if you want an empty bucket.
6. **Sign up again:** Use the driver app → email OTP → onboarding. A new `drivers` row will be created for your user.

## If the script fails

- Note the **table name** in the error. Your DB may have extra FKs or different column names.
- Run the discovery query at the bottom of the SQL file to see what references `drivers` or `auth.users`.
- Comment out or adjust the failing line; ask your backend maintainer if a table is safe to truncate.

## After wipe

- No `drivers` rows → first login creates onboarding flow from scratch.
- Rider data (`ride_requests` as rider bookings) is only **detached** from drivers (`driver_id` cleared) in the default script so you do not lose rider history. If you prefer to delete those rows instead, only do that in a dev database.
