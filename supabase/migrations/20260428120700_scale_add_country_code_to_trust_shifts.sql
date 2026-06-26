-- Migration: Add country_code to driver_trust_scores and driver_shift_sessions
-- Phase 1, Step 1.8 — Needed for per-country analytics and reporting.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE driver_trust_scores
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

ALTER TABLE driver_shift_sessions
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

CREATE INDEX IF NOT EXISTS idx_driver_trust_scores_country
  ON driver_trust_scores (country_code);

CREATE INDEX IF NOT EXISTS idx_driver_shift_sessions_country
  ON driver_shift_sessions (country_code, shift_started_at DESC);
