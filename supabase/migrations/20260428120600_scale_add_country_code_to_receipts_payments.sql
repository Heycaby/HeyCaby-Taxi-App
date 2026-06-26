-- Migration: Add country_code + currency to receipts and driver_payment_events
-- Phase 1, Step 1.7 — Required for multi-currency financial reporting.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL',
  ADD COLUMN IF NOT EXISTS currency     TEXT NOT NULL DEFAULT 'EUR';

ALTER TABLE driver_payment_events
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL',
  ADD COLUMN IF NOT EXISTS currency     TEXT NOT NULL DEFAULT 'EUR';

CREATE INDEX IF NOT EXISTS idx_receipts_country_code
  ON receipts (country_code);

CREATE INDEX IF NOT EXISTS idx_driver_payment_events_country_code
  ON driver_payment_events (country_code);
