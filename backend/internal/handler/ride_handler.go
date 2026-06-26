package handler

import (
	"context"
	"errors"

	"github.com/gofiber/fiber/v2"
	authmw "github.com/heycaby/backend/internal/middleware/auth"
	regionmw "github.com/heycaby/backend/internal/middleware/region"
	rideservice "github.com/heycaby/backend/internal/service/ride_service"
)

type rideService interface {
	Accept(ctx context.Context, rideID, driverID string) error
	Start(ctx context.Context, rideID string) error
	Complete(ctx context.Context, rideID string) error
	Cancel(ctx context.Context, rideID string) error
	CreateManualRide(ctx context.Context, in rideservice.CreateManualRideInput) (*rideservice.CreateManualRideResult, error)
}

// RideHandler exposes additive v1 driver ride lifecycle actions.
type RideHandler struct {
	svc rideService
}

func NewRideHandler(svc rideService) *RideHandler {
	return &RideHandler{svc: svc}
}

// POST /api/v1/driver/ride/:rideId/accept
func (h *RideHandler) Accept(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	rideID := c.Params("rideId")
	if rideID == "" {
		return fiber.ErrBadRequest
	}
	driverID := authmw.GetUID(c)
	if driverID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "missing driver identity")
	}
	if err := h.svc.Accept(c.Context(), rideID, driverID); err != nil {
		if errors.Is(err, rideservice.ErrRideAlreadyAccepted) {
			return fiber.NewError(fiber.StatusConflict, "ride already accepted")
		}
		return err
	}
	return ok(c, fiber.Map{"status": "accepted", "ride_id": rideID})
}

// POST /api/v1/driver/ride/:rideId/start
func (h *RideHandler) Start(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	rideID := c.Params("rideId")
	if rideID == "" {
		return fiber.ErrBadRequest
	}
	if err := h.svc.Start(c.Context(), rideID); err != nil {
		return err
	}
	return ok(c, fiber.Map{"status": "in_progress", "ride_id": rideID})
}

// POST /api/v1/driver/ride/:rideId/complete
func (h *RideHandler) Complete(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	rideID := c.Params("rideId")
	if rideID == "" {
		return fiber.ErrBadRequest
	}
	if err := h.svc.Complete(c.Context(), rideID); err != nil {
		return err
	}
	return ok(c, fiber.Map{"status": "completed", "ride_id": rideID})
}

// POST /api/v1/driver/ride/:rideId/cancel
func (h *RideHandler) Cancel(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	rideID := c.Params("rideId")
	if rideID == "" {
		return fiber.ErrBadRequest
	}
	if err := h.svc.Cancel(c.Context(), rideID); err != nil {
		return err
	}
	return ok(c, fiber.Map{"status": "cancelled", "ride_id": rideID})
}

// POST /api/v1/driver/ride/manual
func (h *RideHandler) CreateManualRide(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	var body struct {
		PickupAddress  string   `json:"pickup_address"`
		DropoffAddress string   `json:"dropoff_address"`
		FareCents      int      `json:"fare_cents"`
		Currency       string   `json:"currency"`
		PaymentMethod  string   `json:"payment_method"`
		PassengerName  string   `json:"passenger_name"`
		PickupLat      *float64 `json:"pickup_lat"`
		PickupLng      *float64 `json:"pickup_lng"`
		DropoffLat     *float64 `json:"dropoff_lat"`
		DropoffLng     *float64 `json:"dropoff_lng"`
	}
	if err := c.BodyParser(&body); err != nil {
		return fiber.ErrBadRequest
	}
	if body.DropoffAddress == "" {
		return fiber.NewError(fiber.StatusBadRequest, "dropoff_address is required")
	}
	if body.FareCents <= 0 {
		return fiber.NewError(fiber.StatusBadRequest, "fare_cents must be > 0")
	}
	if body.PaymentMethod == "" {
		return fiber.NewError(fiber.StatusBadRequest, "payment_method is required")
	}
	result, err := h.svc.CreateManualRide(c.Context(), rideservice.CreateManualRideInput{
		DriverID:       authmw.GetUID(c),
		CountryCode:    regionmw.GetCountryCode(c),
		Currency:       body.Currency,
		PickupAddress:  body.PickupAddress,
		DropoffAddress: body.DropoffAddress,
		FareCents:      body.FareCents,
		PaymentMethod:  body.PaymentMethod,
		PassengerName:  body.PassengerName,
		PickupLat:      body.PickupLat,
		PickupLng:      body.PickupLng,
		DropoffLat:     body.DropoffLat,
		DropoffLng:     body.DropoffLng,
	})
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	}
	return ok(c, fiber.Map{
		"success": true,
		"ride_id": result.RideID,
		"message": "Ride recorded successfully",
		"policy": fiber.Map{
			"platform_fee_cents":      0,
			"commission_applied":      false,
			"driver_keeps_full_fare":  true,
			"recorded_as_manual_ride": true,
		},
	})
}
