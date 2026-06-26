-- Migration: Seed country configs and feature flags into app_config
-- Phase 0, Step 0.3 — ADDITIVE ONLY. Just INSERT new rows. No schema change.
-- Safe to apply immediately. Flutter app does not read these keys yet.
-- DO NOT RUN until reviewed and approved.

INSERT INTO app_config (key, value)
VALUES
  ('country_config.NL', '{
    "currency": "EUR",
    "currency_symbol": "€",
    "weekly_fee": 30,
    "min_earning_before_fee": 100,
    "matching_radius_km": 5,
    "compliance_type": "NL",
    "required_docs": ["kvk", "chauffeurspas", "rijbewijs", "vog", "taxidiploma"],
    "fallback_base_fare": 4.25,
    "fallback_per_km_rate": 1.85,
    "break_reminder_minutes": 120
  }'),
  ('country_config.UK', '{
    "currency": "GBP",
    "currency_symbol": "£",
    "weekly_fee": 30,
    "min_earning_before_fee": 100,
    "matching_radius_km": 5,
    "compliance_type": "UK",
    "required_docs": ["dvla", "pco_license", "insurance"],
    "fallback_base_fare": 3.50,
    "fallback_per_km_rate": 1.60,
    "break_reminder_minutes": 120
  }'),
  ('country_config.NG', '{
    "currency": "NGN",
    "currency_symbol": "₦",
    "weekly_fee": 5000,
    "min_earning_before_fee": 20000,
    "matching_radius_km": 7,
    "compliance_type": "NG",
    "required_docs": ["driver_license", "vehicle_inspection", "insurance"],
    "fallback_base_fare": 500,
    "fallback_per_km_rate": 150,
    "break_reminder_minutes": 180
  }'),
  ('feature_flags', '{
    "use_go_matching": false,
    "use_redis_locations": false,
    "use_go_ride_service": false,
    "force_update_min_version": "1.0.0",
    "marketplace_enabled": true,
    "radar_enabled": true,
    "community_hub_enabled": true,
    "scheduled_rides_enabled": true,
    "return_trips_enabled": true
  }'),
  ('search_config', '{
    "driver_search_window_minutes": 10,
    "no_driver_card_delay_seconds": 5,
    "near_term_scheduled_window_hours": 48,
    "max_search_radius_km": 12.0,
    "driver_location_max_age_minutes": 3
  }')
ON CONFLICT (key) DO NOTHING;
