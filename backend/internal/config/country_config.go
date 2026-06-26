package config

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

// CountryConfig holds all country-specific rules. Loaded from app_config table.
// No business logic is hardcoded — everything reads from here.
type CountryConfig struct {
	Currency             string   `json:"currency"`
	CurrencySymbol       string   `json:"currency_symbol"`
	WeeklyFee            float64  `json:"weekly_fee"`
	MinEarningBeforeFee  float64  `json:"min_earning_before_fee"`
	MatchingRadiusKm     float64  `json:"matching_radius_km"`
	ComplianceType       string   `json:"compliance_type"`
	RequiredDocs         []string `json:"required_docs"`
	FallbackBaseFare     float64  `json:"fallback_base_fare"`
	FallbackPerKmRate    float64  `json:"fallback_per_km_rate"`
	BreakReminderMinutes int      `json:"break_reminder_minutes"`
}

// FeatureFlags controls which backend systems are active. Flipped remotely via app_config.
type FeatureFlags struct {
	UseGoMatching         bool   `json:"use_go_matching"`
	UseGoDriverLocations  bool   `json:"use_go_driver_locations"`
	UseRedisLocations     bool   `json:"use_redis_locations"`
	UseGoRideService      bool   `json:"use_go_ride_service"`
	GoBackendURL          string `json:"go_backend_url"`
	ForceUpdateMinVersion string `json:"force_update_min_version"`
	MarketplaceEnabled    bool   `json:"marketplace_enabled"`
	RadarEnabled          bool   `json:"radar_enabled"`
	CommunityHubEnabled   bool   `json:"community_hub_enabled"`
	ScheduledRidesEnabled bool   `json:"scheduled_rides_enabled"`
	ReturnTripsEnabled    bool   `json:"return_trips_enabled"`
	DriverOnboardingV2    bool   `json:"driver_onboarding_v2"`
}

// SearchConfig holds all tunable timing and radius values. App reads these at boot.
type SearchConfig struct {
	DriverSearchWindowMinutes    int     `json:"driver_search_window_minutes"`
	NoDriverCardDelaySeconds     int     `json:"no_driver_card_delay_seconds"`
	NearTermScheduledWindowHours int     `json:"near_term_scheduled_window_hours"`
	MaxSearchRadiusKm            float64 `json:"max_search_radius_km"`
	DriverLocationMaxAgeMinutes  int     `json:"driver_location_max_age_minutes"`
}

// AppConfigRepository abstracts where app_config is fetched from.
type AppConfigRepository interface {
	GetAppConfigValues(ctx context.Context, keys []string) (map[string]string, error)
}

// CountryConfigService loads and caches all country configs from app_config.
// Thread-safe. Auto-refreshes every 5 minutes.
type CountryConfigService struct {
	mu       sync.RWMutex
	configs  map[string]*CountryConfig
	flags    *FeatureFlags
	search   *SearchConfig
	loadedAt time.Time
	repo     AppConfigRepository
}

func NewCountryConfigService(repo AppConfigRepository) *CountryConfigService {
	return &CountryConfigService{
		repo:    repo,
		configs: make(map[string]*CountryConfig),
		flags:   &FeatureFlags{},
		search:  defaultSearchConfig(),
	}
}

// Load performs the initial blocking load. Call on startup.
func (s *CountryConfigService) Load() error {
	return s.reload(context.Background())
}

// GetCountry returns config for a country code. Triggers async refresh if stale.
func (s *CountryConfigService) GetCountry(code string) (*CountryConfig, bool) {
	s.mu.RLock()
	stale := time.Since(s.loadedAt) > 5*time.Minute
	c, ok := s.configs[code]
	s.mu.RUnlock()

	if stale {
		go func() { _ = s.reload(context.Background()) }()
	}
	return c, ok
}

func (s *CountryConfigService) GetFlags() *FeatureFlags {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.flags
}

func (s *CountryConfigService) GetSearch() *SearchConfig {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.search
}

func (s *CountryConfigService) reload(ctx context.Context) error {
	keys := []string{
		"country_config.NL",
		"country_config.UK",
		"country_config.NG",
		"feature_flags",
		"search_config",
	}
	values, err := s.repo.GetAppConfigValues(ctx, keys)
	if err != nil {
		return fmt.Errorf("reload country config: %w", err)
	}

	configs := make(map[string]*CountryConfig)
	for _, code := range []string{"NL", "UK", "NG"} {
		raw, ok := values["country_config."+code]
		if !ok {
			continue
		}
		var cfg CountryConfig
		if err := json.Unmarshal([]byte(raw), &cfg); err != nil {
			continue
		}
		configs[code] = &cfg
	}

	var flags FeatureFlags
	if raw, ok := values["feature_flags"]; ok {
		_ = json.Unmarshal([]byte(raw), &flags)
	}

	search := defaultSearchConfig()
	if raw, ok := values["search_config"]; ok {
		_ = json.Unmarshal([]byte(raw), search)
	}

	s.mu.Lock()
	s.configs = configs
	s.flags = &flags
	s.search = search
	s.loadedAt = time.Now()
	s.mu.Unlock()
	return nil
}

func defaultSearchConfig() *SearchConfig {
	return &SearchConfig{
		DriverSearchWindowMinutes:    10,
		NoDriverCardDelaySeconds:     5,
		NearTermScheduledWindowHours: 48,
		MaxSearchRadiusKm:            12.0,
		DriverLocationMaxAgeMinutes:  3,
	}
}
