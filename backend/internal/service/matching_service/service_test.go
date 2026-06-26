package matchingservice

import (
	"testing"

	"github.com/heycaby/backend/internal/repository"
	redis "github.com/redis/go-redis/v9"
)

func TestRankDriversByRedisDistance(t *testing.T) {
	locs := []redis.GeoLocation{
		{Name: "d2", Dist: 0.9},
		{Name: "d1", Dist: 0.4},
	}
	drivers := []repository.Driver{
		{ID: "d2", Rating: 4.6},
		{ID: "d1", Rating: 4.2},
	}

	got := rankDriversByRedisDistance(locs, drivers)
	if got[0].ID != "d1" || got[1].ID != "d2" {
		t.Fatalf("unexpected order: got %s,%s want d1,d2", got[0].ID, got[1].ID)
	}
}

func TestRankDriversByRedisDistance_UsesRatingAsTieBreaker(t *testing.T) {
	locs := []redis.GeoLocation{
		{Name: "d1", Dist: 1.0},
		{Name: "d2", Dist: 1.0},
	}
	drivers := []repository.Driver{
		{ID: "d1", Rating: 4.3},
		{ID: "d2", Rating: 4.8},
	}

	got := rankDriversByRedisDistance(locs, drivers)
	if got[0].ID != "d2" || got[1].ID != "d1" {
		t.Fatalf("unexpected order: got %s,%s want d2,d1", got[0].ID, got[1].ID)
	}
}

