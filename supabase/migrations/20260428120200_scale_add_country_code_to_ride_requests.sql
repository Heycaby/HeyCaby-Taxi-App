-- Migration: Add country_code + currency to ride_requests
-- Phase 1, Step 1.3 — ADDITIVE ONLY. All existing requests default to NL/EUR.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE ride_requests
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL',
  ADD COLUMN IF NOT EXISTS currency     TEXT NOT NULL DEFAULT 'EUR';

CREATE INDEX IF NOT EXISTS idx_ride_requests_country_code
  ON ride_requests (country_code);

-- Hot path: searching requests by city (used by matching engine)
CREATE INDEX IF NOT EXISTS idx_ride_requests_pickup_city
  ON ride_requests (pickup_city_id, status, created_at DESC);
