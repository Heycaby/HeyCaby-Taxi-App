-- Migration: Add remaining performance indexes (schema-aligned variant)
-- NOTE: notifications uses read_at (not is_read) in this project schema.

CREATE INDEX IF NOT EXISTS idx_drivers_profile_status
  ON drivers (profile_status);

CREATE INDEX IF NOT EXISTS idx_ride_requests_rider_id_created
  ON ride_requests (rider_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read
  ON notifications (user_id, read_at, created_at DESC);
