-- HOTFIX: trg_bump_driver_total_earnings fires on every INSERT/UPDATE of ride_requests
-- and references NEW.driver_earnings_cents. The column was never added, causing every
-- ride booking and status update to fail with:
--   "record new has no field driver_earnings_cents"
-- Adding as nullable integer (cents) so the trigger guard (IS NOT NULL) keeps it a no-op
-- until the completed-ride flow starts setting the value.

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS driver_earnings_cents integer;
