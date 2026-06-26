package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	authmw "github.com/heycaby/backend/internal/middleware/auth"
	regionmw "github.com/heycaby/backend/internal/middleware/region"
	"github.com/heycaby/backend/internal/repository"
	driverservice "github.com/heycaby/backend/internal/service/driver_service"
)

type mockDriverService struct {
	heartbeatResult *driverservice.HeartbeatResult
	heartbeatErr    error
	setStatusCalls  int
	readinessCalls  int
}

func (m *mockDriverService) Heartbeat(_ context.Context, _ driverservice.HeartbeatInput) (*driverservice.HeartbeatResult, error) {
	return m.heartbeatResult, m.heartbeatErr
}

func (m *mockDriverService) CheckReadiness(_ context.Context, _, _ string, _ bool) (*driverservice.ReadinessResult, error) {
	m.readinessCalls++
	return &driverservice.ReadinessResult{CanGoOnline: true, Checklist: []driverservice.ReadinessItem{}}, nil
}

func (m *mockDriverService) SetStatus(_ context.Context, _, _, _ string, _ bool) (*driverservice.StatusDecision, error) {
	m.setStatusCalls++
	return &driverservice.StatusDecision{Status: "available"}, nil
}

func (m *mockDriverService) ValidateDocument(_ context.Context, _ driverservice.DocumentValidateInput) (*driverservice.DocumentValidateResult, error) {
	return &driverservice.DocumentValidateResult{Valid: true, Cleaned: "12345678"}, nil
}

func (m *mockDriverService) GetBillingStatus(_ context.Context, _ string) (*driverservice.BillingStatus, error) {
	return &driverservice.BillingStatus{}, nil
}

func (m *mockDriverService) CreatePlatformPayment(_ context.Context, _, _ string) (*driverservice.PaymentCreateResult, error) {
	return &driverservice.PaymentCreateResult{}, nil
}

func (m *mockDriverService) VerifyAppleDriverSubscription(_ context.Context, _, _, _ string) error {
	return nil
}

func (m *mockDriverService) ListDriverPayments(_ context.Context, _ string) ([]repository.DriverPaymentEvent, error) {
	return nil, nil
}

func (m *mockDriverService) PauseSubscription(_ context.Context, _ string) error  { return nil }
func (m *mockDriverService) ResumeSubscription(_ context.Context, _ string) error { return nil }
func (m *mockDriverService) CancelSubscription(_ context.Context, _ string) error { return nil }

func TestDriverHeartbeatResponseShape(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	svc := &mockDriverService{
		heartbeatResult: &driverservice.HeartbeatResult{
			PendingRideRequests: []repository.PendingRideRequest{
				{ID: "ride-1", Status: "assigned", CreatedAt: "2026-04-28T18:00:00Z"},
			},
		},
	}
	h := NewDriverHandler(svc)

	app.Use(func(c *fiber.Ctx) error {
		c.Locals(authmw.CtxSupabaseUID, "driver-1")
		c.Locals(authmw.CtxUserRole, "driver")
		c.Locals(regionmw.CtxCountryCode, "NL")
		return c.Next()
	})
	app.Post("/driver/heartbeat", h.Heartbeat)

	reqBody := []byte(`{"lat":52.10,"lng":4.30}`)
	req := httptest.NewRequest(http.MethodPost, "/driver/heartbeat", bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test error: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected status 200, got %d", resp.StatusCode)
	}

	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload["status"] != "ok" {
		t.Fatalf("expected status=ok, got %#v", payload["status"])
	}
	if _, ok := payload["pending_ride_requests"]; !ok {
		t.Fatalf("expected pending_ride_requests key in response")
	}
}

func TestDriverHeartbeatRejectsNonDriver(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	svc := &mockDriverService{
		heartbeatResult: &driverservice.HeartbeatResult{},
	}
	h := NewDriverHandler(svc)

	app.Use(func(c *fiber.Ctx) error {
		c.Locals(authmw.CtxSupabaseUID, "rider-1")
		c.Locals(authmw.CtxUserRole, "rider")
		c.Locals(regionmw.CtxCountryCode, "NL")
		return c.Next()
	})
	app.Post("/driver/heartbeat", h.Heartbeat)

	reqBody := []byte(`{"lat":52.10,"lng":4.30}`)
	req := httptest.NewRequest(http.MethodPost, "/driver/heartbeat", bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test error: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected status 403, got %d", resp.StatusCode)
	}
}

func TestDriverReadinessRejectsNonDriver(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	svc := &mockDriverService{}
	h := NewDriverHandler(svc)

	app.Use(func(c *fiber.Ctx) error {
		c.Locals(authmw.CtxSupabaseUID, "rider-1")
		c.Locals(authmw.CtxUserRole, "rider")
		c.Locals(regionmw.CtxCountryCode, "NL")
		return c.Next()
	})
	app.Get("/driver/readiness", h.Readiness)

	req := httptest.NewRequest(http.MethodGet, "/driver/readiness", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test error: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected status 403, got %d", resp.StatusCode)
	}
	if svc.readinessCalls != 0 {
		t.Fatalf("service should not be called for non-driver role")
	}
}

func TestDriverStatusRejectsNonDriver(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	svc := &mockDriverService{}
	h := NewDriverHandler(svc)

	app.Use(func(c *fiber.Ctx) error {
		c.Locals(authmw.CtxSupabaseUID, "rider-1")
		c.Locals(authmw.CtxUserRole, "rider")
		c.Locals(regionmw.CtxCountryCode, "NL")
		return c.Next()
	})
	app.Post("/driver/status", h.SetStatus)

	reqBody := []byte(`{"status":"available"}`)
	req := httptest.NewRequest(http.MethodPost, "/driver/status", bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test error: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected status 403, got %d", resp.StatusCode)
	}
	if svc.setStatusCalls != 0 {
		t.Fatalf("service should not be called for non-driver role")
	}
}
