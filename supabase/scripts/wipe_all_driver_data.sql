-- =============================================================================
-- WIPE ALL DRIVER DATA + matching Auth users — clean slate for first real driver
-- =============================================================================
-- Run in Supabase SQL Editor (postgres / service role).
--
-- What it does:
--   1. Saves auth user ids from public.drivers (temp table).
--   2. Deletes or updates rows that reference drivers.id / driver users.
--   3. DELETE FROM public.drivers.
--   4. DELETE FROM auth.users for those accounts.
--
-- Adjust before run:
--   - If any DELETE fails (unknown table/column), comment that block out or fix names.
--   - ride_requests: default is SET driver_id = NULL (keeps rider rows). Uncomment
--     the stricter DELETE block only if you really want those rows gone.
--
-- NOT covered automatically:
--   - Storage bucket `driver-documents` (delete objects in Dashboard if needed).
--   - Custom tables not listed below.
-- =============================================================================

BEGIN;

-- 1) Capture auth ids before we touch drivers
CREATE TEMP TABLE _wipe_driver_auth_ids (user_id uuid PRIMARY KEY)
  ON COMMIT DROP;
INSERT INTO _wipe_driver_auth_ids (user_id)
SELECT DISTINCT user_id
FROM public.drivers
WHERE user_id IS NOT NULL;

-- 2) Detach rides from drivers (keeps ride_requests rows for riders/analytics)
UPDATE public.ride_requests
SET
  driver_id = NULL,
  swap_listed = false,
  swap_listed_at = NULL
WHERE driver_id IN (SELECT id FROM public.drivers);

-- Stricter option (DEV ONLY — uncomment if you want to delete driver-assigned rides)
-- DELETE FROM public.ride_requests WHERE driver_id IN (SELECT id FROM public.drivers);

-- 3) Swap listings (see ride_swap_service — offering_driver_id is required)
DELETE FROM public.ride_swaps
WHERE offering_driver_id IN (SELECT id FROM public.drivers);

-- If your DB has a claimer column (e.g. claiming_driver_id), add:
-- OR claiming_driver_id IN (SELECT id FROM public.drivers);

-- Ratings for those drivers (driver_passenger_comments is a VIEW over ride_ratings — delete base rows)
DELETE FROM public.ride_ratings WHERE driver_id IN (SELECT id FROM public.drivers);

-- 4) Driver-scoped tables (Flutter driver_data_service / shift / location / community)
DELETE FROM public.driver_comment_reports WHERE driver_id IN (SELECT id FROM public.drivers);
DELETE FROM public.driver_hidden_comments WHERE driver_id IN (SELECT id FROM public.drivers);
DELETE FROM public.driver_safety_events WHERE driver_id IN (SELECT id FROM public.drivers);
DELETE FROM public.driver_earnings_targets WHERE driver_id IN (SELECT id FROM public.drivers);
DELETE FROM public.driver_rate_profiles WHERE driver_id IN (SELECT id FROM public.drivers);
DELETE FROM public.driver_shift_sessions WHERE driver_id IN (SELECT id FROM public.drivers);
DELETE FROM public.driver_trip_history WHERE driver_id IN (SELECT id FROM public.drivers);
-- driver_return_trips: VIEW in production — do not DELETE
-- driver_market_signals: no driver_id column (zone-level signals) — skip
DELETE FROM public.driver_locations
WHERE driver_id IN (SELECT id FROM public.drivers)
   OR driver_id IN (SELECT user_id FROM public.drivers);

-- Community posts by driver
DELETE FROM public.community_posts WHERE driver_id IN (SELECT id FROM public.drivers);

-- Support tickets (user_id is text in HeyCaby production schema — cast uuid)
DELETE FROM public.tickets WHERE user_id IN (SELECT user_id::text FROM _wipe_driver_auth_ids);

-- 5) Core driver rows
DELETE FROM public.drivers;

-- 6) Auth: remove login accounts for those users
--    If this fails due to FK from another public table to auth.users, delete those rows first
--    or add the missing table to section 4.
DELETE FROM auth.users WHERE id IN (SELECT user_id FROM _wipe_driver_auth_ids);

COMMIT;

-- =============================================================================
-- Verification (run after commit)
-- =============================================================================
-- SELECT count(*) AS drivers_left FROM public.drivers;
-- SELECT count(*) AS auth_left FROM auth.users u
--   WHERE u.id IN (SELECT user_id FROM _wipe_driver_auth_ids);  -- temp gone; use known email instead

-- =============================================================================
-- Discovery helpers (run separately if you need to extend the script)
-- =============================================================================
-- Tables referencing public.drivers:
-- SELECT
--   tc.table_schema,
--   tc.table_name,
--   kcu.column_name,
--   ccu.table_name AS foreign_table_name
-- FROM information_schema.table_constraints AS tc
-- JOIN information_schema.key_column_usage AS kcu
--   ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
-- JOIN information_schema.constraint_column_usage AS ccu
--   ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
-- WHERE tc.constraint_type = 'FOREIGN KEY'
--   AND ccu.table_name = 'drivers'
--   AND ccu.table_schema = 'public';
