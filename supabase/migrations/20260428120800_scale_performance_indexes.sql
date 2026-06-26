-- Migration: Critical performance indexes for scale
-- Phase 1, Step 1.9 — All queries that run on every ride request MUST use indexes.
-- These are safe to add with IF NOT EXISTS. Zero downtime (built CONCURRENTLY when possible).
-- DO NOT RUN until reviewed and approved.

-- Ride requests: driver matching needs fast lookup of 'searching' requests
CREATE INDEX IF NOT EXISTS idx_ride_requests_status_created
  ON ride_requests (status, created_at DESC)
  WHERE status = 'searching';

-- Driver locations: the most critical hot-path index
-- Every rider booking triggers this query
CREATE INDEX IF NOT EXISTS idx_driver_locations_lat_lng
  ON driver_locations (latitude, longitude)
  WHERE driver_id IS NOT NULL;

-- Drivers: admin and ops queries on profile status
CREATE INDEX IF NOT EXISTS idx_drivers_profile_status
  ON drivers (profile_status);

-- Ride requests: rider looking up their own requests
CREATE INDEX IF NOT EXISTS idx_ride_requests_rider_id_created
  ON ride_requests (rider_id, created_at DESC);

-- Rides: driver trip history
CREATE INDEX IF NOT EXISTS idx_rides_driver_id_created
  ON rides (driver_id, created_at DESC);

-- Notifications: unread lookup
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read
  ON notifications (user_id, is_read, created_at DESC);

-- Driver shift sessions: active shift lookup (runs every heartbeat)
CREATE INDEX IF NOT EXISTS idx_driver_shift_sessions_driver_active
  ON driver_shift_sessions (driver_id, is_active)
  WHERE is_active = true;
