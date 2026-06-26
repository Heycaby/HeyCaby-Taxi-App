package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisClient wraps go-redis with HeyCaby-specific helpers.
// Key naming convention: {entity}:{country_code}:{id}
// Example: drivers:NL, ride_lock:abc-123, drivers:NL:driver-uuid:status
type RedisClient struct {
	rdb *redis.Client
}

func NewRedisClient(redisURL string) (*RedisClient, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	rdb := redis.NewClient(opts)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping: %w", err)
	}
	return &RedisClient{rdb: rdb}, nil
}

// --- Driver Location (GEO) ---

const driverHeartbeatTTL = 2 * time.Minute

// UpsertDriverLocation writes a driver's position to the country-scoped GEO set.
// Also refreshes a heartbeat key so auto-offline triggers if pings stop.
func (r *RedisClient) UpsertDriverLocation(ctx context.Context, countryCode, driverID string, lat, lng float64) error {
	geoKey := "drivers:" + countryCode
	pipe := r.rdb.Pipeline()
	pipe.GeoAdd(ctx, geoKey, &redis.GeoLocation{
		Name:      driverID,
		Longitude: lng,
		Latitude:  lat,
	})
	heartbeatKey := fmt.Sprintf("drivers:%s:%s:online", countryCode, driverID)
	pipe.Set(ctx, heartbeatKey, "1", driverHeartbeatTTL)
	_, err := pipe.Exec(ctx)
	return err
}

// RemoveDriverLocation removes a driver from the GEO set (going offline).
func (r *RedisClient) RemoveDriverLocation(ctx context.Context, countryCode, driverID string) error {
	geoKey := "drivers:" + countryCode
	heartbeatKey := fmt.Sprintf("drivers:%s:%s:online", countryCode, driverID)
	pipe := r.rdb.Pipeline()
	pipe.ZRem(ctx, geoKey, driverID)
	pipe.Del(ctx, heartbeatKey)
	_, err := pipe.Exec(ctx)
	return err
}

// NearbyDrivers finds drivers within radiusKm of (lat, lng) for a country.
func (r *RedisClient) NearbyDrivers(ctx context.Context, countryCode string, lat, lng, radiusKm float64) ([]redis.GeoLocation, error) {
	geoKey := "drivers:" + countryCode
	return r.rdb.GeoRadius(ctx, geoKey, lng, lat, &redis.GeoRadiusQuery{
		Radius:    radiusKm,
		Unit:      "km",
		WithCoord: true,
		WithDist:  true,
		Sort:      "ASC",
		Count:     50,
	}).Result()
}

// --- Ride Locking (prevent double assignment) ---

const rideAcceptLockTTL = 15 * time.Second

// LockRide atomically claims a ride for a driver. Returns true if lock acquired.
// Uses SET NX EX — if the key already exists, returns false (another driver claimed it).
func (r *RedisClient) LockRide(ctx context.Context, rideID, driverID string) (bool, error) {
	key := "ride:" + rideID + ":accept_lock"
	return r.rdb.SetNX(ctx, key, driverID, rideAcceptLockTTL).Result()
}

// UnlockRide releases a ride lock (e.g. driver cancelled after accepting).
func (r *RedisClient) UnlockRide(ctx context.Context, rideID string) error {
	return r.rdb.Del(ctx, "ride:"+rideID+":accept_lock").Err()
}

// GetRideLockHolder returns which driver currently holds a ride lock.
func (r *RedisClient) GetRideLockHolder(ctx context.Context, rideID string) (string, error) {
	return r.rdb.Get(ctx, "ride:"+rideID+":accept_lock").Result()
}

// --- Driver Status ---

const driverStatusTTL = 2 * time.Minute

func (r *RedisClient) SetDriverStatus(ctx context.Context, countryCode, driverID, status string) error {
	key := fmt.Sprintf("drivers:%s:%s:status", countryCode, driverID)
	return r.rdb.Set(ctx, key, status, driverStatusTTL).Err()
}

func (r *RedisClient) GetDriverStatus(ctx context.Context, countryCode, driverID string) (string, error) {
	key := fmt.Sprintf("drivers:%s:%s:status", countryCode, driverID)
	return r.rdb.Get(ctx, key).Result()
}

// IsDriverOnline checks if the heartbeat key is still alive.
func (r *RedisClient) IsDriverOnline(ctx context.Context, countryCode, driverID string) (bool, error) {
	key := fmt.Sprintf("drivers:%s:%s:online", countryCode, driverID)
	n, err := r.rdb.Exists(ctx, key).Result()
	return n > 0, err
}

// Ping checks Redis connectivity.
func (r *RedisClient) Ping(ctx context.Context) error {
	return r.rdb.Ping(ctx).Err()
}
