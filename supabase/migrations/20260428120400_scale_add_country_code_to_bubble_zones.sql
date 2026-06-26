-- Migration: Add country_code to bubble_zones, populated from cities relationship
-- Phase 1, Step 1.5 — ADDITIVE ONLY.
-- DO NOT RUN until reviewed and approved.

ALTER TABLE bubble_zones
  ADD COLUMN IF NOT EXISTS country_code TEXT;

-- Backfill from the cities relationship (cities.country_code we just added)
UPDATE bubble_zones bz
SET country_code = c.country_code
FROM cities c
WHERE bz.city_id = c.id
  AND bz.country_code IS NULL;

-- Default any remaining zones to NL (zones without a city link)
UPDATE bubble_zones
SET country_code = 'NL'
WHERE country_code IS NULL;

CREATE INDEX IF NOT EXISTS idx_bubble_zones_country
  ON bubble_zones (country_code);

-- Composite index for zone lookup by country
CREATE INDEX IF NOT EXISTS idx_bubble_zones_country_active
  ON bubble_zones (country_code, is_active)
  WHERE is_active = true;
