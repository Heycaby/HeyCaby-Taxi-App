-- Migration: Add country_code to drivers table
-- Phase 1, Step 1.2 — ADDITIVE ONLY. All existing drivers default to NL.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

CREATE INDEX IF NOT EXISTS idx_drivers_country_code
  ON drivers (country_code);

-- Composite index for the matching query: find available drivers by country
CREATE INDEX IF NOT EXISTS idx_drivers_country_status
  ON drivers (country_code, status);

-- Partial index for the hot path: available drivers only
CREATE INDEX IF NOT EXISTS idx_drivers_country_status_active
  ON drivers (country_code, status)
  WHERE status IN ('available', 'on_ride');
