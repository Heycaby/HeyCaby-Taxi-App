package region

import (
	"context"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

const CtxCountryCode = "country_code"
const CtxProvinceCode = "province_code"
const CtxCityID = "city_id"
const CtxLaunchAllowed = "launch_allowed"
const CtxLaunchReason = "launch_reason"

// New returns middleware that detects and injects country_code into every request context.
//
// Detection order (first match wins):
//  1. JWT user_metadata.country_code (set on driver/rider profile in Supabase)
//  2. X-Country-Code request header (for internal tooling and testing)
//  3. city_id lookup via repository (X-City-Id, city_id, pickup_city_id)
//  3. Default: "NL" (all current users are Netherlands)
func New() fiber.Handler {
	return NewWithCityResolver(nil)
}

type cityResolver interface {
	GetCityRegionByID(ctx context.Context, cityID string) (string, string, bool, error)
	IsLaunchRegionActive(ctx context.Context, countryCode, provinceCode string) (bool, bool, error)
}

// NewWithCityResolver adds city_id -> country/province fallback and launch gating metadata.
func NewWithCityResolver(resolver interface {
	GetCityRegionByID(ctx context.Context, cityID string) (string, string, bool, error)
	IsLaunchRegionActive(ctx context.Context, countryCode, provinceCode string) (bool, bool, error)
}) fiber.Handler {
	return func(c *fiber.Ctx) error {
		code, province, cityID, launchAllowed, launchReason := detectRegionContext(c, resolver)
		c.Locals(CtxCountryCode, code)
		if province != "" {
			c.Locals(CtxProvinceCode, province)
		}
		if cityID != "" {
			c.Locals(CtxCityID, cityID)
		}
		c.Locals(CtxLaunchAllowed, launchAllowed)
		if launchReason != "" {
			c.Locals(CtxLaunchReason, launchReason)
		}
		return c.Next()
	}
}

// GetCountryCode retrieves the injected country code from request context.
func GetCountryCode(c *fiber.Ctx) string {
	if code, ok := c.Locals(CtxCountryCode).(string); ok && code != "" {
		return code
	}
	return "NL"
}

func GetProvinceCode(c *fiber.Ctx) string {
	if code, ok := c.Locals(CtxProvinceCode).(string); ok && code != "" {
		return code
	}
	return ""
}

func IsLaunchAllowed(c *fiber.Ctx) bool {
	if allowed, ok := c.Locals(CtxLaunchAllowed).(bool); ok {
		return allowed
	}
	return true
}

func GetLaunchReason(c *fiber.Ctx) string {
	if reason, ok := c.Locals(CtxLaunchReason).(string); ok {
		return reason
	}
	return ""
}

func detectRegionContext(c *fiber.Ctx, resolver cityResolver) (country, province, cityID string, launchAllowed bool, launchReason string) {
	country = ""
	province = ""
	cityID = ""
	launchAllowed = true
	launchReason = ""

	// 1. From JWT user_metadata (most reliable — set when user registers)
	if code := countryFromJWT(c); code != "" {
		country = code
	}

	// 2. From request header (internal services, admin tools, testing)
	if country == "" {
		if code := c.Get("X-Country-Code"); code != "" {
			country = code
		}
	}

	// 3. From city_id fallback when request is city-scoped.
	if resolver != nil {
		for _, key := range []string{"X-City-Id", "city_id", "pickup_city_id"} {
			rawCityID := c.Get(key)
			if rawCityID == "" {
				rawCityID = c.Query(key)
			}
			rawCityID = strings.TrimSpace(rawCityID)
			if rawCityID == "" {
				continue
			}
			cityID = rawCityID

			metaCountry, metaProvince, metaCityActive, err := resolver.GetCityRegionByID(c.Context(), cityID)
			if err != nil || metaCountry == "" {
				continue
			}
			if country == "" && metaCountry != "" {
				country = metaCountry
			}
			if metaProvince != "" {
				province = metaProvince
			}

			launchAllowed = metaCityActive
			if !metaCityActive {
				launchReason = "city_inactive"
			}
			if metaProvince != "" && metaCountry != "" {
				if provinceActive, found, err := resolver.IsLaunchRegionActive(c.Context(), metaCountry, metaProvince); err == nil && found {
					if !provinceActive {
						launchAllowed = false
						launchReason = "province_inactive"
					}
				}
			}
			break
		}
	}

	// 4. Default to NL — all current production users are Netherlands
	if country == "" {
		country = "NL"
	}
	return country, province, cityID, launchAllowed, launchReason
}

func countryFromJWT(c *fiber.Ctx) string {
	// The auth middleware already validated the JWT and set the user ID.
	// We re-read the raw token here to extract user_metadata.country_code.
	// This is safe: auth middleware ran first and the token is already verified.
	raw := c.Get("Authorization")
	if len(raw) < 8 {
		return ""
	}
	raw = raw[7:] // strip "Bearer "

	// Parse without verification — auth middleware already verified it.
	token, _, err := jwt.NewParser().ParseUnverified(raw, jwt.MapClaims{})
	if err != nil {
		return ""
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return ""
	}

	// user_metadata is set by our app on signup: { country_code: "NL" }
	if um, ok := claims["user_metadata"].(map[string]any); ok {
		if code, ok := um["country_code"].(string); ok && code != "" {
			return code
		}
	}
	return ""
}

