package matchingservice

import (
	"context"
	"fmt"
	"sort"

	"github.com/heycaby/backend/internal/cache"
	"github.com/heycaby/backend/internal/config"
	"github.com/heycaby/backend/internal/repository"
	redis "github.com/redis/go-redis/v9"
)

// MatchingService finds available drivers for a ride request.
// Uses Redis GEO when use_redis_locations=true; falls back to Supabase query.
type MatchingService struct {
	redis   *cache.RedisClient
	drivers *repository.DriverRepository
	cfg     *config.CountryConfigService
}

func New(redis *cache.RedisClient, drivers *repository.DriverRepository, cfg *config.CountryConfigService) *MatchingService {
	return &MatchingService{redis: redis, drivers: drivers, cfg: cfg}
}

// NearbyDrivers returns drivers near (lat, lng) for the given country.
func (s *MatchingService) NearbyDrivers(ctx context.Context, countryCode string, lat, lng float64, riderRadiusKm *float64) ([]repository.Driver, error) {
	cc, ok := s.cfg.GetCountry(countryCode)
	if !ok {
		return nil, fmt.Errorf("unknown country_code: %s", countryCode)
	}

	flags := s.cfg.GetFlags()
	if !flags.UseRedisLocations {
		return nil, fmt.Errorf("redis matching is required but disabled by feature flag")
	}
	if s.redis == nil {
		return nil, fmt.Errorf("redis matching is required but redis is unavailable")
	}

	maxRadiusKm := cc.MatchingRadiusKm
	if riderRadiusKm != nil && *riderRadiusKm > 0 && *riderRadiusKm < maxRadiusKm {
		maxRadiusKm = *riderRadiusKm
	}

	drivers, err := s.nearbyFromRedisInWaves(ctx, countryCode, lat, lng, maxRadiusKm)
	if err != nil {
		return nil, err
	}
	return drivers, nil
}

func waveRadiiForMax(maxRadiusKm float64) []float64 {
	waves := []float64{5, 10, 25}
	out := make([]float64, 0, len(waves))
	for _, w := range waves {
		if w <= maxRadiusKm {
			out = append(out, w)
		}
	}
	if len(out) == 0 || out[len(out)-1] < maxRadiusKm {
		out = append(out, maxRadiusKm)
	}
	return out
}

func (s *MatchingService) nearbyFromRedisInWaves(ctx context.Context, countryCode string, lat, lng, maxRadiusKm float64) ([]repository.Driver, error) {
	waves := waveRadiiForMax(maxRadiusKm)
	seen := map[string]struct{}{}
	out := make([]repository.Driver, 0, 50)

	for _, radiusKm := range waves {
		locs, err := s.redis.NearbyDrivers(ctx, countryCode, lat, lng, radiusKm)
		if err != nil {
			return nil, fmt.Errorf("redis NearbyDrivers (%.1fkm): %w", radiusKm, err)
		}
		if len(locs) == 0 {
			continue
		}

		ids := make([]string, 0, len(locs))
		for _, loc := range locs {
			if _, ok := seen[loc.Name]; ok {
				continue
			}
			ids = append(ids, loc.Name)
		}
		if len(ids) == 0 {
			continue
		}

		drivers, err := s.drivers.GetByIDs(ctx, ids, countryCode)
		if err != nil {
			return nil, err
		}
		ordered := rankDriversByRedisDistance(locs, drivers)
		for _, d := range ordered {
			// Strict personal pickup radius: if driver did not set one, skip.
			if d.PickupDistanceMaxKm <= 0 {
				continue
			}
			if loc, ok := findLocByDriverID(locs, d.ID); ok && loc.Dist <= d.PickupDistanceMaxKm {
				if _, exists := seen[d.ID]; exists {
					continue
				}
				seen[d.ID] = struct{}{}
				out = append(out, d)
			}
		}
	}
	return out, nil
}

func findLocByDriverID(locs []redis.GeoLocation, driverID string) (redis.GeoLocation, bool) {
	for _, loc := range locs {
		if loc.Name == driverID {
			return loc, true
		}
	}
	return redis.GeoLocation{}, false
}

func rankDriversByRedisDistance(locs []redis.GeoLocation, drivers []repository.Driver) []repository.Driver {
	if len(drivers) <= 1 {
		return drivers
	}
	distByID := make(map[string]float64, len(locs))
	for _, loc := range locs {
		distByID[loc.Name] = loc.Dist
	}

	sort.SliceStable(drivers, func(i, j int) bool {
		di, iok := distByID[drivers[i].ID]
		dj, jok := distByID[drivers[j].ID]
		switch {
		case iok && jok && di != dj:
			return di < dj
		case iok != jok:
			return iok
		}
		if drivers[i].Rating != drivers[j].Rating {
			return drivers[i].Rating > drivers[j].Rating
		}
		return drivers[i].ID < drivers[j].ID
	})
	return drivers
}
