-- Remove only production-confirmed exact duplicate indexes.
--
-- Retained canonical indexes:
--   * idx_driver_shift_sessions_driver_active (source-controlled name)
--   * idx_swap_offering_driver (production-used name; 124 scans at audit)
--   * idx_swap_ride_request (production-used name; 13 scans at audit)
--
-- None of the removed indexes backs a constraint, primary key, or uniqueness
-- invariant. Their definitions were byte-for-byte equivalent to the retained
-- indexes apart from the index name.

DROP INDEX IF EXISTS public.idx_shift_sessions_driver_active;
DROP INDEX IF EXISTS public.idx_ride_swaps_offering_driver;
DROP INDEX IF EXISTS public.idx_ride_swaps_ride_request;
