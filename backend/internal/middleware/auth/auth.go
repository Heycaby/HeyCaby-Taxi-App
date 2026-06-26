package auth

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

const (
	CtxUserID        = "user_id"
	CtxUserRole      = "user_role"      // "driver" | "rider"
	CtxSupabaseUID   = "supabase_uid"   // auth.users.id
	CtxReviewAccount = "review_account" // App Store review bypass (user_metadata.review_account)
)

// New returns auth middleware that validates Supabase JWTs.
// The JWT secret comes from Supabase Dashboard → Project Settings → API → JWT Secret.
// Supabase signs all tokens with HS256.
type jwksCache struct {
	mu        sync.RWMutex
	keysByKid map[string]any
	loadedAt  time.Time
}

func (c *jwksCache) get(kid string) (any, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	k, ok := c.keysByKid[kid]
	return k, ok
}

func (c *jwksCache) stale() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return time.Since(c.loadedAt) > 15*time.Minute
}

func (c *jwksCache) set(m map[string]any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.keysByKid = m
	c.loadedAt = time.Now()
}

func New(jwtSecret, supabaseURL string) fiber.Handler {
	secretBytes := []byte(jwtSecret)
	jwksURL := buildJWKSURL(supabaseURL)
	cache := &jwksCache{keysByKid: map[string]any{}}

	return func(c *fiber.Ctx) error {
		raw := extractBearerToken(c)
		if raw == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "missing authorization token",
			})
		}

		claims, err := parseToken(raw, secretBytes, jwksURL, cache)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "invalid token",
			})
		}

		// Supabase puts the user UUID in the "sub" claim.
		sub, _ := claims["sub"].(string)
		if sub == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "invalid token claims",
			})
		}

		// user_metadata.user_type is set by the app on signup: "driver" | "rider"
		role := extractUserType(claims)
		// Driver app signups historically omitted user_type; JWT then defaults to rider → 403 on driver routes.
		if role != "driver" && isDriverAPIPath(c.Path()) && !hasExplicitUserType(claims) {
			role = "driver"
		}

		c.Locals(CtxSupabaseUID, sub)
		c.Locals(CtxUserID, sub)
		c.Locals(CtxUserRole, role)
		c.Locals(CtxReviewAccount, extractReviewAccount(claims))

		return c.Next()
	}
}

func buildJWKSURL(supabaseURL string) string {
	u := strings.TrimRight(strings.TrimSpace(supabaseURL), "/")
	if u == "" {
		return ""
	}
	return u + "/auth/v1/.well-known/jwks.json"
}

// GetUID returns the authenticated user's Supabase UUID from context.
func GetUID(c *fiber.Ctx) string {
	if id, ok := c.Locals(CtxSupabaseUID).(string); ok {
		return id
	}
	return ""
}

// GetRole returns the authenticated user role from context.
func GetRole(c *fiber.Ctx) string {
	if role, ok := c.Locals(CtxUserRole).(string); ok {
		return role
	}
	return ""
}

// GetReviewAccount returns true when JWT user_metadata.review_account is set (App Store review builds).
func GetReviewAccount(c *fiber.Ctx) bool {
	if v, ok := c.Locals(CtxReviewAccount).(bool); ok {
		return v
	}
	return false
}

func extractReviewAccount(claims jwt.MapClaims) bool {
	um, ok := claims["user_metadata"].(map[string]any)
	if !ok {
		return false
	}
	v, ok := um["review_account"]
	if !ok || v == nil {
		return false
	}
	switch t := v.(type) {
	case bool:
		return t
	case string:
		s := strings.TrimSpace(strings.ToLower(t))
		return s == "true" || s == "1" || s == "yes"
	default:
		return false
	}
}

func extractBearerToken(c *fiber.Ctx) string {
	header := c.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return ""
	}
	return strings.TrimPrefix(header, "Bearer ")
}

func parseToken(tokenStr string, secret []byte, jwksURL string, cache *jwksCache) (jwt.MapClaims, error) {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
		switch t.Method.(type) {
		case *jwt.SigningMethodHMAC:
			return secret, nil
		case *jwt.SigningMethodECDSA:
			kid, _ := t.Header["kid"].(string)
			if kid == "" || jwksURL == "" {
				return nil, fiber.ErrUnauthorized
			}
			if cache != nil {
				if k, ok := cache.get(kid); ok {
					return k, nil
				}
				if cache.stale() || len(cache.keysByKid) == 0 {
					if m, loadErr := fetchJWKS(jwksURL); loadErr == nil {
						cache.set(m)
						if k, ok := m[kid]; ok {
							return k, nil
						}
					}
				}
			}
			// one direct fetch fallback
			m, loadErr := fetchJWKS(jwksURL)
			if loadErr != nil {
				return nil, fiber.ErrUnauthorized
			}
			if cache != nil {
				cache.set(m)
			}
			k, ok := m[kid]
			if !ok {
				return nil, fiber.ErrUnauthorized
			}
			return k, nil
		default:
			return nil, fiber.ErrUnauthorized
		}
	})
	if err != nil || !token.Valid {
		return nil, fiber.ErrUnauthorized
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fiber.ErrUnauthorized
	}
	return claims, nil
}

func fetchJWKS(jwksURL string) (map[string]any, error) {
	parsed, err := url.Parse(jwksURL)
	if err != nil {
		return nil, err
	}
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest(http.MethodGet, parsed.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return nil, fiber.ErrUnauthorized
	}
	var payload struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			Crv string `json:"crv"`
			X   string `json:"x"`
			Y   string `json:"y"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}
	out := map[string]any{}
	for _, k := range payload.Keys {
		if strings.ToUpper(k.Kty) != "EC" || strings.ToUpper(k.Crv) != "P-256" || k.Kid == "" {
			continue
		}
		xBytes, err1 := base64.RawURLEncoding.DecodeString(k.X)
		yBytes, err2 := base64.RawURLEncoding.DecodeString(k.Y)
		if err1 != nil || err2 != nil {
			continue
		}
		pub := &ecdsa.PublicKey{
			Curve: elliptic.P256(),
			X:     new(big.Int).SetBytes(xBytes),
			Y:     new(big.Int).SetBytes(yBytes),
		}
		out[k.Kid] = pub
	}
	if len(out) == 0 {
		return nil, fiber.ErrUnauthorized
	}
	return out, nil
}

func isDriverAPIPath(path string) bool {
	return strings.Contains(path, "/driver/")
}

func hasExplicitUserType(claims jwt.MapClaims) bool {
	if um, ok := claims["user_metadata"].(map[string]any); ok {
		if t, ok := um["user_type"].(string); ok && strings.TrimSpace(t) != "" {
			return true
		}
	}
	if am, ok := claims["app_metadata"].(map[string]any); ok {
		if t, ok := am["user_type"].(string); ok && strings.TrimSpace(t) != "" {
			return true
		}
	}
	return false
}

// extractUserType reads user_metadata.user_type from the JWT.
// Falls back to app_metadata.user_type, then "rider" as safe default.
func extractUserType(claims jwt.MapClaims) string {
	if extractReviewAccount(claims) {
		return "driver"
	}
	if um, ok := claims["user_metadata"].(map[string]any); ok {
		if t, ok := um["user_type"].(string); ok && t != "" {
			return t
		}
	}
	if am, ok := claims["app_metadata"].(map[string]any); ok {
		if t, ok := am["user_type"].(string); ok && t != "" {
			return t
		}
	}
	return "rider"
}
