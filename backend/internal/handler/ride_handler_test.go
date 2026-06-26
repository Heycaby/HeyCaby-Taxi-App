package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	authmw "github.com/heycaby/backend/internal/middleware/auth"
	rideservice "github.com/heycaby/backend/internal/service/ride_service"
)

type mockRideService struct {
	lastAction string
	lastRideID string
	lastDriver string
}

func (m *mockRideService) Accept(_ context.Context, rideID, driverID string) error {
	m.lastAction = "accepted"
	m.lastRideID = rideID
	m.lastDriver = driverID
	return nil
}
func (m *mockRideService) Start(_ context.Context, rideID string) error {
	m.lastAction = "in_progress"
	m.lastRideID = rideID
	return nil
}
func (m *mockRideService) Complete(_ context.Context, rideID string) error {
	m.lastAction = "completed"
	m.lastRideID = rideID
	return nil
}
func (m *mockRideService) Cancel(_ context.Context, rideID string) error {
	m.lastAction = "cancelled"
	m.lastRideID = rideID
	return nil
}
func (m *mockRideService) CreateManualRide(_ context.Context, _ rideservice.CreateManualRideInput) (*rideservice.CreateManualRideResult, error) {
	m.lastAction = "manual"
	return &rideservice.CreateManualRideResult{RideID: "ride-manual-test"}, nil
}

func TestRideHandlerAccept(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	svc := &mockRideService{}
	h := NewRideHandler(svc)
	app.Use(func(c *fiber.Ctx) error {
		c.Locals(authmw.CtxUserRole, "driver")
		c.Locals(authmw.CtxSupabaseUID, "driver-123")
		return c.Next()
	})
	app.Post("/driver/ride/:rideId/accept", h.Accept)

	req := httptest.NewRequest(http.MethodPost, "/driver/ride/ride-123/accept", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test error: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	if svc.lastAction != "accepted" || svc.lastRideID != "ride-123" || svc.lastDriver != "driver-123" {
		t.Fatalf("unexpected call: action=%s ride=%s driver=%s", svc.lastAction, svc.lastRideID, svc.lastDriver)
	}
}

func TestRideHandlerAcceptRejectsNonDriver(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	svc := &mockRideService{}
	h := NewRideHandler(svc)
	app.Use(func(c *fiber.Ctx) error {
		c.Locals(authmw.CtxUserRole, "rider")
		return c.Next()
	})
	app.Post("/driver/ride/:rideId/accept", h.Accept)

	req := httptest.NewRequest(http.MethodPost, "/driver/ride/ride-123/accept", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test error: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", resp.StatusCode)
	}
	if svc.lastAction != "" {
		t.Fatalf("service should not be called for non-driver role")
	}
}
