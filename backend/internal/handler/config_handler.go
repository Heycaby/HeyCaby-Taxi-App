package handler

import (
	"github.com/gofiber/fiber/v2"

	"github.com/heycaby/backend/internal/config"
	regionmw "github.com/heycaby/backend/internal/middleware/region"
)

// ConfigProvider gives the handler access to country config and feature flags.
type ConfigProvider interface {
	GetCountry(code string) (*config.CountryConfig, bool)
	GetFlags() *config.FeatureFlags
	GetSearch() *config.SearchConfig
}

// ConfigHandler handles GET /api/v1/config
// This is the boot endpoint every app calls on startup.
// Returns country config, feature flags, search tuning, and support URLs.
type ConfigHandler struct {
	cfg               ConfigProvider
	skipGoOnlineGates bool
}

func NewConfigHandler(cfg ConfigProvider, skipGoOnlineGates bool) *ConfigHandler {
	return &ConfigHandler{cfg: cfg, skipGoOnlineGates: skipGoOnlineGates}
}

// GetConfig returns the full boot configuration for the requesting client.
// The Flutter app caches this for 5 minutes and uses it to drive all tuneable behaviour.
func (h *ConfigHandler) GetConfig(c *fiber.Ctx) error {
	countryCode := regionmw.GetCountryCode(c)

	countryCfg, found := h.cfg.GetCountry(countryCode)
	if !found {
		// Fallback to NL if country not configured yet
		countryCfg, _ = h.cfg.GetCountry("NL")
	}

	flags := h.cfg.GetFlags()
	search := h.cfg.GetSearch()

	resp := fiber.Map{
		"country_code":            countryCode,
		"min_app_version":         flags.ForceUpdateMinVersion,
		"force_update":            false,
		"search_radius_km":        search.MaxSearchRadiusKm,
		"search_window_minutes":   search.DriverSearchWindowMinutes,
		"no_driver_delay_seconds": search.NoDriverCardDelaySeconds,
		"break_reminder_minutes":  120,
		"search": fiber.Map{
			"driver_search_window_minutes":     search.DriverSearchWindowMinutes,
			"no_driver_card_delay_seconds":     search.NoDriverCardDelaySeconds,
			"near_term_scheduled_window_hours": search.NearTermScheduledWindowHours,
			"max_search_radius_km":             search.MaxSearchRadiusKm,
			"driver_location_max_age_minutes":  search.DriverLocationMaxAgeMinutes,
		},
		"feature_flags": fiber.Map{
			"use_go_matching":         flags.UseGoMatching,
			"use_go_driver_locations": flags.UseGoDriverLocations,
			"use_redis_locations":     flags.UseRedisLocations,
			"use_go_ride_service":     flags.UseGoRideService,
			"go_backend_url":          flags.GoBackendURL,
			"marketplace_enabled":     flags.MarketplaceEnabled,
			"radar_enabled":           flags.RadarEnabled,
			"community_hub_enabled":   flags.CommunityHubEnabled,
			"scheduled_rides_enabled": flags.ScheduledRidesEnabled,
			"return_trips_enabled":    flags.ReturnTripsEnabled,
			"skip_go_online_gates":    h.skipGoOnlineGates,
		},
		"support": fiber.Map{
			"driver_help_url": "https://heycaby.nl/help/drivers",
			"rider_help_url":  "https://heycaby.nl/help/riders",
		},
		"strings": fiber.Map{
			"go_online_button":         "Go Online",
			"payment_required_message": "Payment required before going online",
		},
		"legal": fiber.Map{
			"terms_url":   "https://heycaby.nl/terms",
			"privacy_url": "https://heycaby.nl/privacy",
		},
	}

	// Attach country-specific fields if config is loaded
	if countryCfg != nil {
		resp["currency"] = countryCfg.Currency
		resp["currency_symbol"] = countryCfg.CurrencySymbol
	} else {
		resp["currency"] = "EUR"
		resp["currency_symbol"] = "€"
	}

	return ok(c, resp)
}
