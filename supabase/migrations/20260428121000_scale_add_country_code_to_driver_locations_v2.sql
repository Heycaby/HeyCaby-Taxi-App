-- Migration: Add country_code to driver_locations (schema-aligned variant)
-- NOTE: This project uses current_zone_id (not zone_id) in driver_locations.

ALTER TABLE driver_locations
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'NL';

CREATE INDEX IF NOT EXISTS idx_driver_locations_country
  ON driver_locations (country_code);

CREATE INDEX IF NOT EXISTS idx_driver_locations_country_fresh
  ON driver_locations (country_code, updated_at DESC)
  WHERE driver_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_driver_locations_zone_country
  ON driver_locations (current_zone_id, country_code)
  WHERE current_zone_id IS NOT NULL;
