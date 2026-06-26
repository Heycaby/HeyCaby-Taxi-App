package handler

import (
	"context"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/heycaby/backend/internal/config"
)

// Pinger can check connectivity to a dependency.
type Pinger interface {
	Ping(ctx context.Context) error
}

type FlagProvider interface {
	GetFlags() *config.FeatureFlags
}

// HealthHandler handles GET /health — used by Railway/Render health checks.
type HealthHandler struct {
	redis Pinger
	flags FlagProvider
}

func NewHealthHandler(redis Pinger, flags FlagProvider) *HealthHandler {
	return &HealthHandler{redis: redis, flags: flags}
}

// Health returns 200 if all dependencies are reachable, 503 if not.
func (h *HealthHandler) Health(c *fiber.Ctx) error {
	return h.health(c, false)
}

// Readiness returns strict readiness for dark deploy checks.
// It fails when Redis is required by flags but unavailable.
func (h *HealthHandler) Readiness(c *fiber.Ctx) error {
	return h.health(c, true)
}

func (h *HealthHandler) health(c *fiber.Ctx, strict bool) error {
	ctx, cancel := context.WithTimeout(c.Context(), 2*time.Second)
	defer cancel()

	flags := &config.FeatureFlags{}
	if h.flags != nil && h.flags.GetFlags() != nil {
		flags = h.flags.GetFlags()
	}
	redisRequired := flags.UseRedisLocations || flags.UseGoDriverLocations || flags.UseGoMatching

	status := fiber.Map{
		"status":         "ok",
		"timestamp":      time.Now().UTC().Format(time.RFC3339),
		"strict":         strict,
		"redis_required": redisRequired,
	}

	if h.redis == nil {
		status["redis"] = "disabled"
		if strict && redisRequired {
			status["status"] = "degraded"
			return c.Status(fiber.StatusServiceUnavailable).JSON(status)
		}
		return ok(c, status)
	}

	if err := h.redis.Ping(ctx); err != nil {
		status["status"] = "degraded"
		status["redis"] = "unreachable"
		if strict || redisRequired {
			return c.Status(fiber.StatusServiceUnavailable).JSON(status)
		}
		return ok(c, status)
	}
	status["redis"] = "ok"

	return ok(c, status)
}
