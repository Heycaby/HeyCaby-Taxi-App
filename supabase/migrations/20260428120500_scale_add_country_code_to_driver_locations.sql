-- Migration: Add country_code to driver_locations
-- Phase 1, Step 1.6 — CRITICAL for matching isolation. NL drivers must never appear
-- in UK queries. This is the table that feeds the matching engine.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE driver_locations
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

CREATE INDEX IF NOT EXISTS idx_driver_locations_country
  ON driver_locations (country_code);

-- Composite index for the matching query: country + freshness
-- This runs on every ride request from every rider.
CREATE INDEX IF NOT EXISTS idx_driver_locations_country_fresh
  ON driver_locations (country_code, updated_at DESC)
  WHERE driver_id IS NOT NULL;

-- Zone-based lookup (used by radar and zone matching)
CREATE INDEX IF NOT EXISTS idx_driver_locations_zone_country
  ON driver_locations (zone_id, country_code)
  WHERE zone_id IS NOT NULL;
