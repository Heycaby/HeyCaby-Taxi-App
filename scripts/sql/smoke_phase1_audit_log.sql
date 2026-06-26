-- Phase 1 smoke test: ride_audit_log (run against staging clone, not production without approval)
-- Usage: psql or Supabase SQL editor on staging

BEGIN;

-- 1) Insert synthetic ride (rollback at end)
INSERT INTO public.ride_requests (
  pickup_address,
  destination_address,
  status,
  country_code,
  currency
) VALUES (
  'Smoke Test Pickup',
  'Smoke Test Dropoff',
  'pending',
  'NL',
  'EUR'
)
RETURNING id \gset

SELECT :'id' AS smoke_ride_id;

-- Expect ride.created
SELECT event, metadata->>'status' AS status
FROM public.ride_audit_log
WHERE ride_id = :'id'::uuid
ORDER BY occurred_at;

-- 2) Status transition
UPDATE public.ride_requests
SET status = 'cancelled', cancelled_by = 'system', cancellation_reason = 'smoke_test'
WHERE id = :'id'::uuid;

SELECT event
FROM public.ride_audit_log
WHERE ride_id = :'id'::uuid
ORDER BY occurred_at;

-- Expect at least: ride.created, ride.status_changed, ride.cancelled
SELECT count(*) >= 3 AS phase1_audit_ok
FROM public.ride_audit_log
WHERE ride_id = :'id'::uuid;

ROLLBACK;
