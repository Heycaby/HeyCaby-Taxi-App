package driverservice

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/heycaby/backend/internal/repository"
)

const (
	// foundingEarningsCapCents is platform-tracked earnings before founding drivers #1–200 must subscribe.
	foundingEarningsCapCents = 10000 // €100.00
	// maxFoundingStarterSlot: founding drivers in slots 1–200 get deferred billing until cap; #201+ pay from day one.
	maxFoundingStarterSlot = 200
)

type PlanDefinition struct {
	Code         string `json:"code"`
	Title        string `json:"title"`
	Description  string `json:"description"`
	AmountCents  int    `json:"amount_cents"`
	DurationDays int    `json:"duration_days"`
}

var billingPlans = []PlanDefinition{
	{
		Code:         "daily",
		Title:        "€12.10 per day",
		Description:  "€10 excl. VAT + 21% · 24h access.",
		AmountCents:  1210, // €10 + 21% BTW
		DurationDays: 1,
	},
	{
		Code:         "weekly",
		Title:        "€72.60 per week",
		Description:  "€60 excl. VAT + 21% · 7-day access.",
		AmountCents:  7260, // €60 + 21% BTW
		DurationDays: 7,
	},
	{
		Code:         "monthly",
		Title:        "€242.00 per month",
		Description:  "€200 excl. VAT + 21% · 30-day access.",
		AmountCents:  24200, // €200 + 21% BTW
		DurationDays: 30,
	},
}

type BillingStatus struct {
	BillingProvider          string           `json:"billing_provider"`
	PaymentRequired          bool             `json:"payment_required"`
	WeeklyFeeCents           int              `json:"weekly_fee_cents"`
	SubscriptionStatus       string           `json:"subscription_status"`
	BillingStatusLabel       string           `json:"billing_status_label"`
	StarterPeriodActive      bool             `json:"starter_period_active"`
	StarterEarningsCapCents  int              `json:"starter_earnings_cap_cents,omitempty"`
	StarterEarningsUsedCents int              `json:"starter_earnings_used_cents,omitempty"`
	StarterMessage           string           `json:"starter_message,omitempty"`
	SubscriptionExpiresAt    string           `json:"subscription_expires_at,omitempty"`
	NextPaymentDueAt         string           `json:"next_payment_due_at,omitempty"`
	AllowOneOffCheckout      bool             `json:"allow_one_off_checkout"`
	HasMollieSubscription    bool             `json:"has_mollie_subscription"`
	Plans                    []PlanDefinition `json:"plans"`
}

type PaymentCreateResult struct {
	CheckoutURL     string `json:"checkoutUrl"`
	MolliePaymentID string `json:"mollie_payment_id,omitempty"`
}

type MollieConfig struct {
	APIKey      string
	RedirectURL string
	HTTPTimeout time.Duration
}

type mollieClient struct {
	apiKey      string
	redirectURL string
	httpClient  *http.Client
}

func newMollieClient(cfg MollieConfig) *mollieClient {
	timeout := cfg.HTTPTimeout
	if timeout <= 0 {
		timeout = 15 * time.Second
	}
	return &mollieClient{
		apiKey:      strings.TrimSpace(cfg.APIKey),
		redirectURL: strings.TrimSpace(cfg.RedirectURL),
		httpClient:  &http.Client{Timeout: timeout},
	}
}

type molliePaymentResponse struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Links  struct {
		Checkout struct {
			Href string `json:"href"`
		} `json:"checkout"`
	} `json:"_links"`
}

func (m *mollieClient) configured() bool {
	return m != nil && m.apiKey != ""
}

func (m *mollieClient) createPayment(ctx context.Context, amountCents int, description string, metadata map[string]any) (*molliePaymentResponse, error) {
	if !m.configured() {
		return nil, fmt.Errorf("mollie api key not configured")
	}
	redirect := m.redirectURL
	if redirect == "" {
		redirect = "https://api.heycaby.nl/driver/payment/return"
	}
	body := map[string]any{
		"amount": map[string]string{
			"currency": "EUR",
			"value":    fmt.Sprintf("%.2f", float64(amountCents)/100.0),
		},
		"description": description,
		"redirectUrl": redirect,
		"metadata":    metadata,
	}
	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.mollie.com/v2/payments", bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+m.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := m.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out molliePaymentResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("mollie create payment failed: status %d", resp.StatusCode)
	}
	return &out, nil
}

func (m *mollieClient) fetchPayment(ctx context.Context, paymentID string) (*molliePaymentResponse, error) {
	if !m.configured() {
		return nil, fmt.Errorf("mollie api key not configured")
	}
	u := "https://api.mollie.com/v2/payments/" + url.PathEscape(paymentID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+m.apiKey)
	req.Header.Set("Accept", "application/json")
	resp, err := m.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out molliePaymentResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("mollie get payment failed: status %d", resp.StatusCode)
	}
	return &out, nil
}

func lookupPlan(code string) (PlanDefinition, bool) {
	normalized := strings.ToLower(strings.TrimSpace(code))
	for _, p := range billingPlans {
		if p.Code == normalized {
			return p, true
		}
	}
	return PlanDefinition{}, false
}

// foundingStarterPeriodActive implements founding-driver rule: slots 1–200 stay on starter until
// platform earnings reach €100; founding slot >200 (and all non-founding drivers) require subscription from day one.
func foundingStarterPeriodActive(p *repository.DriverBillingProfile) bool {
	if p == nil || !p.IsFoundingDriver {
		return false
	}
	n := p.FoundingNumber
	if n < 1 || n > maxFoundingStarterSlot {
		return false
	}
	return p.TotalEarningsCents < foundingEarningsCapCents
}

func (s *DriverService) GetBillingStatus(ctx context.Context, driverID string) (*BillingStatus, error) {
	profile, err := s.drivers.GetBillingProfile(ctx, driverID)
	if err != nil {
		return nil, err
	}
	_ = s.syncRecentPayments(ctx, driverID, profile)
	profile, err = s.drivers.GetBillingProfile(ctx, driverID)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	starterActive := foundingStarterPeriodActive(profile)
	subscriptionActive := profile.SubscriptionExpiresAt != nil && profile.SubscriptionExpiresAt.After(now)

	// Default: weekly plan gross (€60 + 21% BTW) for UI when profile has no custom weekly_rate_euros.
	weeklyFeeCents := 7260
	if profile.WeeklyRateEuros > 0 {
		weeklyFeeCents = int(profile.WeeklyRateEuros * 100)
	}

	paymentRequired := !starterActive && !subscriptionActive
	if s.skipGoOnlineGates {
		paymentRequired = false
	}

	out := &BillingStatus{
		BillingProvider:       s.billingProvider,
		PaymentRequired:       paymentRequired,
		WeeklyFeeCents:        weeklyFeeCents,
		SubscriptionStatus:    "inactive",
		BillingStatusLabel:    "Payment required",
		StarterPeriodActive:   starterActive,
		AllowOneOffCheckout:   true,
		HasMollieSubscription: strings.TrimSpace(profile.MollieSubscriptionID) != "",
		Plans:                 billingPlans,
	}
	if s.skipGoOnlineGates {
		out.BillingStatusLabel = "E2E test mode (payment not required)"
		out.SubscriptionStatus = "test"
		return out, nil
	}
	if starterActive {
		out.StarterEarningsCapCents = foundingEarningsCapCents
		out.StarterEarningsUsedCents = max(profile.TotalEarningsCents, 0)
		out.SubscriptionStatus = "starter"
		out.BillingStatusLabel = "Founding starter active"
		out.StarterMessage = fmt.Sprintf(
			"Founding driver starter active: €%.2f of €100.00 used.",
			float64(out.StarterEarningsUsedCents)/100.0,
		)
		return out, nil
	}
	if subscriptionActive {
		out.PaymentRequired = false
		out.SubscriptionStatus = "active"
		out.BillingStatusLabel = "Active"
		ts := profile.SubscriptionExpiresAt.UTC().Format(time.RFC3339)
		out.SubscriptionExpiresAt = ts
		out.NextPaymentDueAt = ts
	}
	return out, nil
}

func (s *DriverService) CreatePlatformPayment(ctx context.Context, driverID string, planCode string) (*PaymentCreateResult, error) {
	status, err := s.GetBillingStatus(ctx, driverID)
	if err != nil {
		return nil, err
	}
	if !status.PaymentRequired {
		return nil, fmt.Errorf("payment not required")
	}
	if strings.TrimSpace(s.billingProvider) == "apple" {
		return nil, ErrBillingUseAppStoreIAP
	}
	plan, ok := lookupPlan(planCode)
	if !ok {
		return nil, fmt.Errorf("invalid plan: use daily, weekly, or monthly")
	}
	if s.mollie == nil || !s.mollie.configured() {
		return nil, fmt.Errorf("billing provider is not configured")
	}
	meta := map[string]any{
		"driver_id":     driverID,
		"plan_code":     plan.Code,
		"duration_days": plan.DurationDays,
	}
	payment, err := s.mollie.createPayment(
		ctx,
		plan.AmountCents,
		fmt.Sprintf("HeyCaby %s plan", plan.Code),
		meta,
	)
	if err != nil {
		return nil, err
	}
	event, err := s.drivers.InsertDriverPaymentEvent(ctx, repository.DriverPaymentEvent{
		DriverID:        driverID,
		AmountCents:     plan.AmountCents,
		Currency:        "EUR",
		Status:          "open",
		Provider:        "mollie",
		MolliePaymentID: payment.ID,
		Metadata:        meta,
	})
	if err == nil && event != nil {
		_ = s.drivers.UpdateDriverPaymentEvent(ctx, event.ID, payment.Status, "", event.Metadata)
	}
	return &PaymentCreateResult{
		CheckoutURL:     payment.Links.Checkout.Href,
		MolliePaymentID: payment.ID,
	}, nil
}

func (s *DriverService) ListDriverPayments(ctx context.Context, driverID string) ([]repository.DriverPaymentEvent, error) {
	_ = s.syncRecentPayments(ctx, driverID, nil)
	return s.drivers.ListDriverPaymentEvents(ctx, driverID, 100)
}

func (s *DriverService) PauseSubscription(ctx context.Context, driverID string) error {
	return s.drivers.CancelSubscription(ctx, driverID)
}

func (s *DriverService) ResumeSubscription(ctx context.Context, _ string) error {
	return nil
}

func (s *DriverService) CancelSubscription(ctx context.Context, driverID string) error {
	return s.drivers.CancelSubscription(ctx, driverID)
}

func (s *DriverService) syncRecentPayments(ctx context.Context, driverID string, profile *repository.DriverBillingProfile) error {
	if strings.TrimSpace(s.billingProvider) == "apple" {
		return nil
	}
	if s.mollie == nil || !s.mollie.configured() {
		return nil
	}
	if driverID == "" {
		return nil
	}
	items, err := s.drivers.ListDriverPaymentEvents(ctx, driverID, 10)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	for _, item := range items {
		if item.MolliePaymentID == "" {
			continue
		}
		switch strings.ToLower(strings.TrimSpace(item.Status)) {
		case "paid", "canceled", "cancelled", "failed", "expired":
			continue
		}
		p, err := s.mollie.fetchPayment(ctx, item.MolliePaymentID)
		if err != nil {
			continue
		}
		status := strings.ToLower(strings.TrimSpace(p.Status))
		_ = s.drivers.UpdateDriverPaymentEvent(ctx, item.ID, status, "", item.Metadata)
		if status == "paid" {
			days := 7
			if v, ok := item.Metadata["duration_days"]; ok {
				switch n := v.(type) {
				case float64:
					if int(n) > 0 {
						days = int(n)
					}
				case int:
					if n > 0 {
						days = n
					}
				}
			}
			base := now
			if profile != nil && profile.SubscriptionExpiresAt != nil && profile.SubscriptionExpiresAt.After(base) {
				base = profile.SubscriptionExpiresAt.UTC()
			}
			_ = s.drivers.SetSubscriptionExpiry(ctx, driverID, base.Add(time.Duration(days)*24*time.Hour))
		}
	}
	return nil
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
