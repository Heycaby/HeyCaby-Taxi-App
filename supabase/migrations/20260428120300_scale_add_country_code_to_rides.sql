-- Migration: Add country_code + currency to rides table
-- Phase 1, Step 1.4 — ADDITIVE ONLY. All existing rides default to NL/EUR.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL',
  ADD COLUMN IF NOT EXISTS currency     TEXT NOT NULL DEFAULT 'EUR';

CREATE INDEX IF NOT EXISTS idx_rides_country_code
  ON rides (country_code);
