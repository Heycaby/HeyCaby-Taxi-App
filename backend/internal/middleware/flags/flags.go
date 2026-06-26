package flags

import (
	"github.com/gofiber/fiber/v2"

	"github.com/heycaby/backend/internal/config"
)

const ctxFlags = "feature_flags"

// FlagProvider supplies current feature flags.
type FlagProvider interface {
	GetFlags() *config.FeatureFlags
}

// New injects feature flags into every request context.
// Handlers read flags via GetFlags(c) to route between old and new systems.
func New(provider FlagProvider) fiber.Handler {
	return func(c *fiber.Ctx) error {
		c.Locals(ctxFlags, provider.GetFlags())
		return c.Next()
	}
}

// GetFlags retrieves the injected feature flags from request context.
func GetFlags(c *fiber.Ctx) *config.FeatureFlags {
	if f, ok := c.Locals(ctxFlags).(*config.FeatureFlags); ok && f != nil {
		return f
	}
	// Safe defaults: everything off = old Supabase behaviour preserved.
	return &config.FeatureFlags{}
}
