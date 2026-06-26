-- Migration: Add country_code, timezone, currency to cities table
-- Phase 1, Step 1.1 — ADDITIVE ONLY. Zero downtime. All existing cities default to NL.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE cities
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL',
  ADD COLUMN IF NOT EXISTS timezone     TEXT NOT NULL DEFAULT 'Europe/Amsterdam',
  ADD COLUMN IF NOT EXISTS currency     TEXT NOT NULL DEFAULT 'EUR';

-- All existing cities are Netherlands (Rotterdam, Amsterdam, Den Haag, Utrecht)
UPDATE cities
SET
  country_code = 'NL',
  timezone     = 'Europe/Amsterdam',
  currency     = 'EUR'
WHERE country_code = 'NL'; -- no-op but explicit

CREATE INDEX IF NOT EXISTS idx_cities_country_code ON cities (country_code);
