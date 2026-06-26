package handler

import (
	"context"
	"errors"

	"github.com/gofiber/fiber/v2"
	authmw "github.com/heycaby/backend/internal/middleware/auth"
	regionmw "github.com/heycaby/backend/internal/middleware/region"
	"github.com/heycaby/backend/internal/repository"
	driverservice "github.com/heycaby/backend/internal/service/driver_service"
)

// DriverHandler exposes driver state endpoints.
type DriverHandler struct {
	svc driverService
}

type driverService interface {
	Heartbeat(ctx context.Context, in driverservice.HeartbeatInput) (*driverservice.HeartbeatResult, error)
	CheckReadiness(ctx context.Context, driverID, countryCode string, reviewAccount bool) (*driverservice.ReadinessResult, error)
	SetStatus(ctx context.Context, driverID, countryCode, status string, reviewAccount bool) (*driverservice.StatusDecision, error)
	ValidateDocument(ctx context.Context, in driverservice.DocumentValidateInput) (*driverservice.DocumentValidateResult, error)
	GetBillingStatus(ctx context.Context, driverID string) (*driverservice.BillingStatus, error)
	CreatePlatformPayment(ctx context.Context, driverID string, planCode string) (*driverservice.PaymentCreateResult, error)
	VerifyAppleDriverSubscription(ctx context.Context, driverID, receiptData, planCode string) error
	ListDriverPayments(ctx context.Context, driverID string) ([]repository.DriverPaymentEvent, error)
	PauseSubscription(ctx context.Context, driverID string) error
	ResumeSubscription(ctx context.Context, driverID string) error
	CancelSubscription(ctx context.Context, driverID string) error
}

func NewDriverHandler(svc driverService) *DriverHandler {
	return &DriverHandler{svc: svc}
}

// POST /api/v1/driver/heartbeat
func (h *DriverHandler) Heartbeat(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	var body struct {
		Lat float64 `json:"lat"`
		Lng float64 `json:"lng"`
	}
	if err := c.BodyParser(&body); err != nil {
		return fiber.ErrBadRequest
	}

	driverID := authmw.GetUID(c)
	countryCode := regionmw.GetCountryCode(c)

	result, err := h.svc.Heartbeat(c.Context(), driverservice.HeartbeatInput{
		DriverID:    driverID,
		CountryCode: countryCode,
		Lat:         body.Lat,
		Lng:         body.Lng,
	})
	if err != nil {
		return err
	}
	return ok(c, fiber.Map{
		"status":                "ok",
		"pending_ride_requests": result.PendingRideRequests,
	})
}

// GET /api/v1/driver/readiness
func (h *DriverHandler) Readiness(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	driverID := authmw.GetUID(c)
	countryCode := regionmw.GetCountryCode(c)
	reviewAccount := authmw.GetReviewAccount(c)

	result, err := h.svc.CheckReadiness(c.Context(), driverID, countryCode, reviewAccount)
	if err != nil {
		return err
	}
	return ok(c, result)
}

// POST /api/v1/driver/status
func (h *DriverHandler) SetStatus(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	var body struct {
		Status string `json:"status"`
	}
	if err := c.BodyParser(&body); err != nil || body.Status == "" {
		return fiber.ErrBadRequest
	}

	valid := map[string]bool{"available": true, "offline": true, "on_break": true}
	if !valid[body.Status] {
		return fiber.NewError(fiber.StatusBadRequest, "invalid status: must be available, offline, or on_break")
	}

	driverID := authmw.GetUID(c)
	countryCode := regionmw.GetCountryCode(c)
	reviewAccount := authmw.GetReviewAccount(c)

	decision, err := h.svc.SetStatus(c.Context(), driverID, countryCode, body.Status, reviewAccount)
	if err != nil {
		return err
	}
	if decision == nil {
		return ok(c, fiber.Map{"status": body.Status})
	}
	return ok(c, decision)
}

// POST /api/v1/driver/document/validate
func (h *DriverHandler) ValidateDocument(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	var body struct {
		DocType string `json:"doc_type"`
		Value   string `json:"value"`
	}
	if err := c.BodyParser(&body); err != nil || body.DocType == "" {
		return fiber.ErrBadRequest
	}

	driverID := authmw.GetUID(c)
	countryCode := regionmw.GetCountryCode(c)
	result, err := h.svc.ValidateDocument(c.Context(), driverservice.DocumentValidateInput{
		DriverID:    driverID,
		CountryCode: countryCode,
		DocType:     body.DocType,
		Value:       body.Value,
	})
	if err != nil {
		return err
	}
	return ok(c, result)
}

// GET /api/driver/status
func (h *DriverHandler) BillingStatus(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	driverID := authmw.GetUID(c)
	status, err := h.svc.GetBillingStatus(c.Context(), driverID)
	if err != nil {
		return err
	}
	// Same contract as SetStatus(available): JWT user_metadata.review_account skips the weekly-fee
	// requirement so App Store Review can go online with a non-paying test account.
	if authmw.GetReviewAccount(c) && status != nil {
		status.PaymentRequired = false
		status.BillingStatusLabel = "App Store review"
	}
	return ok(c, status)
}

// POST /api/driver/payment/create
func (h *DriverHandler) CreatePlatformPayment(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	var body struct {
		Plan string `json:"plan"`
	}
	_ = c.BodyParser(&body)
	plan := body.Plan
	if plan == "" {
		plan = "weekly"
	}
	driverID := authmw.GetUID(c)
	out, err := h.svc.CreatePlatformPayment(c.Context(), driverID, plan)
	if err != nil {
		if errors.Is(err, driverservice.ErrBillingUseAppStoreIAP) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Use App Store In-App Purchase on iOS",
				"code":  "USE_APP_STORE_IAP",
			})
		}
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	}
	return ok(c, out)
}

// POST /api/driver/billing/apple/verify — validates App Store receipt and sets subscription_expires_at.
func (h *DriverHandler) AppleVerifyReceipt(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	var body struct {
		ReceiptData string `json:"receipt_data"`
		PlanCode    string `json:"plan_code"`
	}
	if err := c.BodyParser(&body); err != nil {
		return fiber.ErrBadRequest
	}
	driverID := authmw.GetUID(c)
	if err := h.svc.VerifyAppleDriverSubscription(c.Context(), driverID, body.ReceiptData, body.PlanCode); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	}
	return ok(c, fiber.Map{"ok": true})
}

// GET /api/driver/payments
func (h *DriverHandler) BillingHistory(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	driverID := authmw.GetUID(c)
	items, err := h.svc.ListDriverPayments(c.Context(), driverID)
	if err != nil {
		return err
	}
	return ok(c, fiber.Map{"payments": items})
}

// POST /api/driver/subscription/pause
func (h *DriverHandler) PauseSubscription(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	driverID := authmw.GetUID(c)
	if err := h.svc.PauseSubscription(c.Context(), driverID); err != nil {
		return err
	}
	return ok(c, fiber.Map{"ok": true})
}

// POST /api/driver/subscription/resume
func (h *DriverHandler) ResumeSubscription(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	driverID := authmw.GetUID(c)
	if err := h.svc.ResumeSubscription(c.Context(), driverID); err != nil {
		return err
	}
	return ok(c, fiber.Map{"ok": true})
}

// POST /api/driver/subscription/cancel
func (h *DriverHandler) CancelSubscription(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	driverID := authmw.GetUID(c)
	if err := h.svc.CancelSubscription(c.Context(), driverID); err != nil {
		return err
	}
	return ok(c, fiber.Map{"ok": true})
}

// GET /api/driver/payment/methods-portal
func (h *DriverHandler) PaymentMethodsPortal(c *fiber.Ctx) error {
	if authmw.GetRole(c) != "driver" {
		return fiber.NewError(fiber.StatusForbidden, "driver role required")
	}
	return fiber.NewError(fiber.StatusNotImplemented, "payment methods portal not configured yet")
}
