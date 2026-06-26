package auth

import (
	"testing"

	"github.com/golang-jwt/jwt/v5"
)

func TestIsDriverAPIPath(t *testing.T) {
	if !isDriverAPIPath("/api/v1/driver/status") {
		t.Fatal("expected driver path")
	}
	if !isDriverAPIPath("/api/driver/readiness") {
		t.Fatal("expected legacy driver path")
	}
	if isDriverAPIPath("/api/v1/rider/book") {
		t.Fatal("rider path must not match")
	}
}

func TestHasExplicitUserType(t *testing.T) {
	claims := jwt.MapClaims{
		"user_metadata": map[string]any{"user_type": "rider"},
	}
	if !hasExplicitUserType(claims) {
		t.Fatal("expected explicit rider")
	}
	empty := jwt.MapClaims{"user_metadata": map[string]any{}}
	if hasExplicitUserType(empty) {
		t.Fatal("empty metadata is not explicit")
	}
}
