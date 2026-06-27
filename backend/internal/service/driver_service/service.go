package driverservice

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/heycaby/backend/internal/cache"
	"github.com/heycaby/backend/internal/config"
	"github.com/heycaby/backend/internal/repository"
	emailservice "github.com/heycaby/backend/internal/service/email_service"
)

// DriverService manages driver state: heartbeats, readiness, status.
type DriverService struct {
	redis             *cache.RedisClient
	drivers           *repository.DriverRepository
	cfg               *config.CountryConfigService
	email             emailservice.Service
	mollie            *mollieClient
	billingProvider   string
	appleSharedSecret string
	skipGoOnlineGates bool
}

func New(redis *cache.RedisClient, drivers *repository.DriverRepository, cfg *config.CountryConfigService, email emailservice.Service) *DriverService {
	return &DriverService{
		redis:             redis,
		drivers:           drivers,
		cfg:               cfg,
		email:             email,
		skipGoOnlineGates: false,
	}
}

// SkipGoOnlineGates reports E2E test mode (no document or billing blocks for going available).
func (s *DriverService) SkipGoOnlineGates() bool {
	return s.skipGoOnlineGates
}

// BillingConfig wires Mollie (optional) and App Store receipt verification.
// Provider: "apple" | "mollie". If empty, uses "apple" when AppleSharedSecret is set, otherwise "mollie".
//
// SkipGoOnlineGates: when true, document + billing checks are bypassed for going available (E2E only).
type BillingConfig struct {
	Mollie            MollieConfig
	Provider          string
	AppleSharedSecret string
	SkipGoOnlineGates bool
}

func resolveBillingProvider(explicit, appleSecret string) string {
	e := strings.ToLower(strings.TrimSpace(explicit))
	if e == "apple" || e == "mollie" {
		return e
	}
	if strings.TrimSpace(appleSecret) != "" {
		return "apple"
	}
	return "mollie"
}

func NewWithBilling(
	redis *cache.RedisClient,
	drivers *repository.DriverRepository,
	cfg *config.CountryConfigService,
	email emailservice.Service,
	billing BillingConfig,
) *DriverService {
	provider := resolveBillingProvider(billing.Provider, billing.AppleSharedSecret)
	return &DriverService{
		redis:             redis,
		drivers:           drivers,
		cfg:               cfg,
		email:             email,
		mollie:            newMollieClient(billing.Mollie),
		billingProvider:   provider,
		appleSharedSecret: strings.TrimSpace(billing.AppleSharedSecret),
		skipGoOnlineGates: billing.SkipGoOnlineGates,
	}
}

// HeartbeatInput carries a driver's GPS ping.
type HeartbeatInput struct {
	DriverID    string
	CountryCode string
	Lat         float64
	Lng         float64
}

type HeartbeatResult struct {
	PendingRideRequests []repository.PendingRideRequest `json:"pending_ride_requests"`
}

// Heartbeat processes a 30-second driver ping: updates Redis GEO (if enabled) + Supabase audit.
func (s *DriverService) Heartbeat(ctx context.Context, in HeartbeatInput) (*HeartbeatResult, error) {
	resolvedID, err := s.resolveDriverID(ctx, in.DriverID)
	if err != nil {
		return nil, err
	}
	in.DriverID = resolvedID

	flags := s.cfg.GetFlags()
	useRedisLocations := flags.UseRedisLocations || flags.UseGoDriverLocations
	if useRedisLocations && s.redis != nil {
		if err := s.redis.UpsertDriverLocation(ctx, in.CountryCode, in.DriverID, in.Lat, in.Lng); err != nil {
			return nil, fmt.Errorf("heartbeat redis: %w", err)
		}
	}

	// Keep DB writes best-effort to reduce heartbeat tail latency.
	go func(driverID, countryCode string, lat, lng float64) {
		bgCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = s.drivers.UpsertLocation(bgCtx, driverID, countryCode, lat, lng)
	}(in.DriverID, in.CountryCode, in.Lat, in.Lng)

	pending, err := s.drivers.GetPendingRideRequestsForDriver(ctx, in.DriverID, in.CountryCode, 5)
	if err != nil {
		// Keep heartbeat resilient even when pending ride lookup has transient issues.
		pending = nil
	}

	return &HeartbeatResult{
		PendingRideRequests: pending,
	}, nil
}

// ReadinessResult describes whether a driver may go online.
type ReadinessResult struct {
	CanGoOnline       bool            `json:"can_go_online"`
	GatesSkipped      bool            `json:"gates_skipped,omitempty"`
	Reason            string          `json:"reason,omitempty"`
	MissingDocs       []string        `json:"missing_docs,omitempty"`
	Checklist         []ReadinessItem `json:"checklist"`
	StatusMessage     string          `json:"status_message,omitempty"`
	ComplianceType    string          `json:"compliance_type,omitempty"`
	CompletedRides    int             `json:"completed_rides,omitempty"`
	NextMilestoneAt   int             `json:"next_milestone_at,omitempty"`
	OnboardingV2Stage int             `json:"onboarding_v2_stage,omitempty"`
}

type ReadinessItem struct {
	Key      string `json:"key"`
	Label    string `json:"label"`
	Complete bool   `json:"complete"`
	Action   string `json:"action,omitempty"`
	Note     string `json:"note,omitempty"`
}

type StatusDecision struct {
	Status        string `json:"status"`
	BlockedReason string `json:"blocked_reason,omitempty"`
	Message       string `json:"message,omitempty"`
}

type DocumentValidateInput struct {
	DriverID    string
	CountryCode string
	DocType     string
	Value       string
}

type DocumentValidateResult struct {
	Valid   bool   `json:"valid"`
	Cleaned string `json:"cleaned,omitempty"`
	Error   string `json:"error,omitempty"`
}

// CheckReadiness evaluates driver compliance requirements for their country.
// reviewAccount skips strict checks when the JWT carries user_metadata.review_account (App Store review).
func (s *DriverService) CheckReadiness(ctx context.Context, driverID, countryCode string, reviewAccount bool) (*ReadinessResult, error) {
	cc := strings.ToUpper(strings.TrimSpace(countryCode))
	if !reviewAccount {
		resolvedID, err := s.resolveDriverID(ctx, driverID)
		if err != nil {
			return nil, err
		}
		driverID = resolvedID
	}

	if reviewAccount {
		return &ReadinessResult{
			CanGoOnline: true,
			Checklist: []ReadinessItem{{
				Key:      "review_account",
				Label:    "Review account (App Store)",
				Complete: true,
				Note:     "Compliance checks bypassed for review",
			}},
			StatusMessage:  "Review account bypass",
			ComplianceType: strings.ToLower(cc),
		}, nil
	}

	if s.skipGoOnlineGates {
		compliance, _ := s.drivers.GetCompliance(ctx, driverID)
		var checklist []ReadinessItem
		if compliance != nil {
			checklist = buildReadinessChecklist(compliance, cc)
		} else {
			checklist = []ReadinessItem{{
				Key:      "test_mode",
				Label:    "E2E test mode",
				Complete: true,
				Note:     "Compliance profile optional in test mode",
			}}
		}
		for i := range checklist {
			checklist[i].Complete = true
			if strings.TrimSpace(checklist[i].Note) == "" {
				checklist[i].Note = "Bypassed: E2E go-online test mode"
			}
		}
		return &ReadinessResult{
			CanGoOnline:    true,
			GatesSkipped:   true,
			Checklist:      checklist,
			StatusMessage:  "Test mode: go-online gates bypassed",
			ComplianceType: strings.ToLower(cc),
		}, nil
	}

	compliance, err := s.drivers.GetCompliance(ctx, driverID)
	if err != nil {
		return nil, fmt.Errorf("CheckReadiness: %w", err)
	}

	checklist := buildReadinessChecklist(compliance, cc)
	onboardingV2 := s.cfg != nil && s.cfg.GetFlags().DriverOnboardingV2
	completedRides := 0
	nextMilestone := 0
	v2Stage := 0
	if onboardingV2 {
		if n, err := s.drivers.CountCompletedRides(ctx, driverID); err == nil {
			completedRides = n
		}
		nextMilestone = onboardingV2NextMilestone(completedRides)
		v2Stage = onboardingV2Stage(completedRides)
		checklist = annotateChecklistDeferredV2(checklist, completedRides)
	}
	requiredKeys := onboardingV2RequiredKeysFor(completedRides)
	missing := missingFromChecklist(checklist)
	if onboardingV2 {
		missing = missingForKeys(checklist, requiredKeys)
	}
	if len(missing) > 0 {
		statusMsg := fmt.Sprintf("%d item(s) missing before going online", len(missing))
		if onboardingV2 {
			statusMsg = onboardingV2BlockedMessage(completedRides, len(missing))
		}
		return &ReadinessResult{
			CanGoOnline:       false,
			Reason:            "missing_docs",
			MissingDocs:       missing,
			Checklist:         checklist,
			StatusMessage:     statusMsg,
			ComplianceType:    strings.ToLower(cc),
			CompletedRides:    completedRides,
			NextMilestoneAt:   nextMilestone,
			OnboardingV2Stage: v2Stage,
		}, nil
	}

	now := time.Now()
	if onboardingV2 {
		if completedRides >= onboardingV2Milestone50 {
			if compliance.ChauffeurspasExpiry != nil && compliance.ChauffeurspasExpiry.Before(now) {
				return &ReadinessResult{
					CanGoOnline:       false,
					Reason:            "chauffeurspas_expired",
					Checklist:         checklist,
					StatusMessage:       "Chauffeurspas has expired",
					ComplianceType:    strings.ToLower(cc),
					CompletedRides:    completedRides,
					NextMilestoneAt:   nextMilestone,
					OnboardingV2Stage: v2Stage,
				}, nil
			}
			if compliance.TaxiInsuranceExpiry != nil && compliance.TaxiInsuranceExpiry.Before(now) {
				return &ReadinessResult{
					CanGoOnline:       false,
					Reason:            "taxi_insurance_expired",
					Checklist:         checklist,
					StatusMessage:     "Taxi insurance has expired",
					ComplianceType:    strings.ToLower(cc),
					CompletedRides:    completedRides,
					NextMilestoneAt:   nextMilestone,
					OnboardingV2Stage: v2Stage,
				}, nil
			}
		}
		return &ReadinessResult{
			CanGoOnline:       true,
			Checklist:         checklist,
			StatusMessage:     onboardingV2ReadyMessage(completedRides),
			ComplianceType:    strings.ToLower(cc),
			CompletedRides:    completedRides,
			NextMilestoneAt:   nextMilestone,
			OnboardingV2Stage: v2Stage,
		}, nil
	}
	if compliance.ChauffeurspasExpiry != nil && compliance.ChauffeurspasExpiry.Before(now) {
		return &ReadinessResult{
			CanGoOnline:    false,
			Reason:         "chauffeurspas_expired",
			Checklist:      checklist,
			StatusMessage:  "Chauffeurspas has expired",
			ComplianceType: strings.ToLower(cc),
		}, nil
	}
	if compliance.TaxiInsuranceExpiry != nil && compliance.TaxiInsuranceExpiry.Before(now) {
		return &ReadinessResult{
			CanGoOnline:    false,
			Reason:         "taxi_insurance_expired",
			Checklist:      checklist,
			StatusMessage:  "Taxi insurance has expired",
			ComplianceType: strings.ToLower(cc),
		}, nil
	}

	return &ReadinessResult{
		CanGoOnline:    true,
		Checklist:      checklist,
		StatusMessage:  "Ready to go online",
		ComplianceType: strings.ToLower(cc),
	}, nil
}

// SetStatus updates the driver's status in DB and Redis.
func (s *DriverService) SetStatus(ctx context.Context, driverID, countryCode, status string, reviewAccount bool) (*StatusDecision, error) {
	if !reviewAccount {
		resolvedID, err := s.resolveDriverID(ctx, driverID)
		if err != nil {
			return nil, err
		}
		driverID = resolvedID
	}

	if status == "available" {
		readiness, err := s.CheckReadiness(ctx, driverID, countryCode, reviewAccount)
		if err != nil {
			return nil, err
		}
		if !readiness.CanGoOnline {
			s.sendComplianceBlockedEmail(ctx, driverID, countryCode, readiness)
			return &StatusDecision{
				Status:        "offline",
				BlockedReason: readiness.Reason,
				Message:       readiness.StatusMessage,
			}, nil
		}
		if !reviewAccount && !s.skipGoOnlineGates {
			billing, err := s.GetBillingStatus(ctx, driverID)
			if err != nil {
				return nil, err
			}
			if billing.PaymentRequired {
				return &StatusDecision{
					Status:        "offline",
					BlockedReason: "payment_required",
					Message:       "Payment required before going online",
				}, nil
			}
		}
	}

	if err := s.drivers.SetStatus(ctx, driverID, status); err != nil {
		return nil, err
	}
	if s.redis != nil {
		if err := s.redis.SetDriverStatus(ctx, countryCode, driverID, status); err != nil {
			return nil, err
		}
	}
	return &StatusDecision{
		Status:  status,
		Message: "Status updated",
	}, nil
}

func (s *DriverService) sendComplianceBlockedEmail(ctx context.Context, driverID, countryCode string, readiness *ReadinessResult) {
	if s.email == nil || readiness == nil {
		return
	}
	blockedReason := strings.TrimSpace(readiness.Reason)
	if blockedReason == "" {
		return
	}

	contact, err := s.drivers.GetContact(ctx, driverID)
	if err != nil {
		return
	}
	nowDay := time.Now().UTC().Format("2006-01-02")
	idempotencyKey := fmt.Sprintf("driver_compliance_blocked_v1:%s:%s:%s", driverID, blockedReason, nowDay)

	existing, err := s.drivers.FindEmailEventByIdempotency(ctx, idempotencyKey)
	if err == nil && existing != nil {
		return
	}

	payload := map[string]any{
		"driver_id":      driverID,
		"driver_name":    contact.FullName,
		"country_code":   countryCode,
		"blocked_reason": blockedReason,
		"status_message": readiness.StatusMessage,
		"checklist_url":  "/driver/documents",
	}
	event, err := s.drivers.CreateEmailEvent(ctx, &repository.DriverEmailEvent{
		DriverID:       driverID,
		EventType:      "driver_compliance_blocked_v1",
		TemplateID:     "driver_compliance_blocked_v1",
		IdempotencyKey: idempotencyKey,
		RecipientEmail: contact.Email,
		Payload:        payload,
		Status:         "queued",
		AttemptCount:   0,
	})
	if err != nil {
		return
	}

	msg := renderComplianceBlockedEmail(contact.FullName, readiness.StatusMessage, blockedReason)
	result, sendErr := s.email.Send(ctx, emailservice.Message{
		To:             contact.Email,
		Subject:        msg.Subject,
		TextBody:       msg.TextBody,
		HTMLBody:       msg.HTMLBody,
		TemplateID:     "driver_compliance_blocked_v1",
		IdempotencyKey: idempotencyKey,
	})
	if sendErr != nil && result == nil {
		_ = s.drivers.UpdateEmailEventStatus(ctx, event.ID, "failed", 1, "", sendErr.Error())
		return
	}
	if result == nil {
		_ = s.drivers.UpdateEmailEventStatus(ctx, event.ID, "failed", 1, "", "empty_dispatch_result")
		return
	}
	_ = s.drivers.UpdateEmailEventStatus(
		ctx,
		event.ID,
		result.Status,
		result.AttemptCount,
		result.ProviderMessageID,
		result.Error,
	)
}

type renderedEmail struct {
	Subject  string
	TextBody string
	HTMLBody string
}

func renderComplianceBlockedEmail(driverName, statusMessage, blockedReason string) renderedEmail {
	name := strings.TrimSpace(driverName)
	if name == "" {
		name = "Driver"
	}
	reason := strings.ReplaceAll(strings.TrimSpace(blockedReason), "_", " ")
	subject := "Action required: update your driver documents"
	text := fmt.Sprintf(
		"Hi %s,\n\nYou tried going online, but your account is currently blocked for compliance reasons.\n\nReason: %s\nStatus: %s\n\nOpen the Driver Documents section in the app to fix this and go online again.\n\nHeyCaby Team",
		name,
		reason,
		strings.TrimSpace(statusMessage),
	)
	html := fmt.Sprintf(
		"<p>Hi %s,</p><p>You tried going online, but your account is currently blocked for compliance reasons.</p><p><strong>Reason:</strong> %s<br/><strong>Status:</strong> %s</p><p>Open the Driver Documents section in the app to fix this and go online again.</p><p>HeyCaby Team</p>",
		name,
		reason,
		strings.TrimSpace(statusMessage),
	)
	return renderedEmail{
		Subject:  subject,
		TextBody: text,
		HTMLBody: html,
	}
}

func (s *DriverService) ValidateDocument(_ context.Context, in DocumentValidateInput) (*DocumentValidateResult, error) {
	docType := strings.ToLower(strings.TrimSpace(in.DocType))
	raw := strings.TrimSpace(in.Value)
	if raw == "" {
		return &DocumentValidateResult{
			Valid: false,
			Error: "Document value is required",
		}, nil
	}

	digitsOnly := regexp.MustCompile(`\D+`).ReplaceAllString(raw, "")
	switch docType {
	case "chauffeurspas":
		if len(digitsOnly) < 8 || len(digitsOnly) > 12 {
			return &DocumentValidateResult{
				Valid: false,
				Error: "Chauffeurspas must contain 8 to 12 digits",
			}, nil
		}
		return &DocumentValidateResult{Valid: true, Cleaned: digitsOnly}, nil
	case "kvk":
		if len(digitsOnly) != 8 {
			return &DocumentValidateResult{
				Valid: false,
				Error: "KVK number must contain exactly 8 digits",
			}, nil
		}
		return &DocumentValidateResult{Valid: true, Cleaned: digitsOnly}, nil
	case "taxi_insurance":
		if len(raw) < 6 {
			return &DocumentValidateResult{
				Valid: false,
				Error: "Insurance policy number looks too short",
			}, nil
		}
		return &DocumentValidateResult{Valid: true, Cleaned: strings.ToUpper(raw)}, nil
	default:
		return &DocumentValidateResult{
			Valid: false,
			Error: "Unsupported document type",
		}, nil
	}
}

func buildReadinessChecklist(c *repository.DriverCompliance, countryCode string) []ReadinessItem {
	cc := strings.ToUpper(strings.TrimSpace(countryCode))
	items := make([]ReadinessItem, 0, 20)

	// Shared with Flutter `driver_go_online_policy.dart` (legal + photos).
	items = append(items,
		ReadinessItem{
			Key:      "profile_photo",
			Label:    "Profile photo",
			Complete: strings.TrimSpace(c.ProfilePhotoURL) != "",
			Action:   "/driver/profile/photo",
		},
		ReadinessItem{
			Key:      "vehicle_photos",
			Label:    "Vehicle photos",
			Complete: hasNonEmptyVehiclePhoto(c.VehiclePhotoURLs),
			Action:   "/driver/vehicle",
		},
		ReadinessItem{
			Key:      "terms_of_service",
			Label:    "Terms of service accepted",
			Complete: c.TermsAcceptedAt != nil,
			Action:   "/driver/terms",
		},
		ReadinessItem{
			Key:      "indemnification_quiz",
			Label:    "Indemnification read & quiz passed",
			Complete: c.IndemnificationReadAt != nil && c.IndemnificationQuizPassed,
			Action:   "/driver/indemnification",
			Note:     "Read the indemnification document and pass the short quiz",
		},
	)

	switch cc {
	case "NL":
		items = append(items,
			ReadinessItem{
				Key:      "kvk_number",
				Label:    "KVK number",
				Complete: strings.TrimSpace(c.KvkNumber) != "",
				Action:   "/driver/documents/kvk",
			},
			ReadinessItem{
				Key:      "kvk_address",
				Label:    "KVK business address",
				Complete: strings.TrimSpace(c.KvkAddress) != "",
				Action:   "/driver/documents/kvk",
			},
			ReadinessItem{
				Key:      "chauffeurspas",
				Label:    "Chauffeurspas (number & expiry)",
				Complete: strings.TrimSpace(c.ChauffeurspasNumber) != "" && c.ChauffeurspasExpiry != nil,
				Action:   "/driver/documents/chauffeurspas",
			},
			ReadinessItem{
				Key:      "taxi_insurance",
				Label:    "Taxi insurance (provider, policy, photo & expiry)",
				Complete: nlTaxiInsuranceComplete(c),
				Action:   "/driver/documents/insurance",
			},
			ReadinessItem{
				Key:      "vehicle_plate",
				Label:    "Vehicle plate",
				Complete: strings.TrimSpace(c.VehiclePlate) != "",
				Action:   "/driver/vehicle",
			},
			ReadinessItem{
				Key:      "rijbewijs_verified",
				Label:    "Driving licence verified by admin",
				Complete: c.RijbewijsVerified,
				Action:   "/driver/documents",
				Note:     "Admin confirms licence after review (e.g. Veriff)",
			},
		)
	case "UK":
		items = append(items,
			ReadinessItem{
				Key:      "insurance",
				Label:    "Insurance policy number",
				Complete: strings.TrimSpace(c.TaxiInsurancePolicyNumber) != "",
				Action:   "/driver/documents/insurance",
			},
			ReadinessItem{
				Key:      "vehicle_plate",
				Label:    "Vehicle plate",
				Complete: strings.TrimSpace(c.VehiclePlate) != "",
				Action:   "/driver/vehicle",
			},
		)
	case "NG":
		items = append(items, ReadinessItem{
			Key:      "insurance",
			Label:    "Insurance policy number",
			Complete: strings.TrimSpace(c.TaxiInsurancePolicyNumber) != "",
			Action:   "/driver/documents/insurance",
		})
	default:
		items = append(items, ReadinessItem{
			Key:      "vehicle_plate",
			Label:    "Vehicle plate",
			Complete: strings.TrimSpace(c.VehiclePlate) != "",
			Action:   "/driver/vehicle",
		})
	}
	return items
}

var onboardingV2RequiredKeys = map[string]struct{}{
	"vehicle_plate":        {},
	"terms_of_service":     {},
	"indemnification_quiz": {},
}

const (
	onboardingV2Milestone20 = 20
	onboardingV2Milestone50 = 50
)

var onboardingV2Milestone20Keys = map[string]struct{}{
	"kvk_number":      {},
	"kvk_address":     {},
	"chauffeurspas":   {},
	"profile_photo":   {},
	"vehicle_photos":  {},
}

var onboardingV2Milestone50Keys = map[string]struct{}{
	"taxi_insurance":      {},
	"rijbewijs_verified": {},
}

func onboardingV2RequiredKeysFor(completedRides int) map[string]struct{} {
	required := make(map[string]struct{}, len(onboardingV2RequiredKeys)+len(onboardingV2Milestone20Keys)+len(onboardingV2Milestone50Keys))
	for k := range onboardingV2RequiredKeys {
		required[k] = struct{}{}
	}
	if completedRides >= onboardingV2Milestone20 {
		for k := range onboardingV2Milestone20Keys {
			required[k] = struct{}{}
		}
	}
	if completedRides >= onboardingV2Milestone50 {
		for k := range onboardingV2Milestone50Keys {
			required[k] = struct{}{}
		}
	}
	return required
}

func onboardingV2NextMilestone(completedRides int) int {
	if completedRides < onboardingV2Milestone20 {
		return onboardingV2Milestone20
	}
	if completedRides < onboardingV2Milestone50 {
		return onboardingV2Milestone50
	}
	return 0
}

func onboardingV2Stage(completedRides int) int {
	if completedRides < onboardingV2Milestone20 {
		return 0
	}
	if completedRides < onboardingV2Milestone50 {
		return 1
	}
	return 2
}

func onboardingV2BlockedMessage(completedRides, missingCount int) string {
	if completedRides >= onboardingV2Milestone50 {
		return fmt.Sprintf("After %d rides: full verification required (%d item(s) missing)", onboardingV2Milestone50, missingCount)
	}
	if completedRides >= onboardingV2Milestone20 {
		return fmt.Sprintf("After %d rides: KvK, chauffeurspas and photos required (%d item(s) missing)", onboardingV2Milestone20, missingCount)
	}
	return fmt.Sprintf("Plate + legal minimum required (%d item(s) missing)", missingCount)
}

func onboardingV2ReadyMessage(completedRides int) string {
	if completedRides >= onboardingV2Milestone50 {
		return "Onboarding V2: full verification met"
	}
	if completedRides >= onboardingV2Milestone20 {
		return "Onboarding V2: milestone 20 met — complete docs before 50 rides"
	}
	return "Onboarding V2: plate + legal minimum met"
}

func missingForKeys(checklist []ReadinessItem, required map[string]struct{}) []string {
	missing := make([]string, 0, len(required))
	for _, item := range checklist {
		if item.Complete {
			continue
		}
		if _, ok := required[item.Key]; ok {
			missing = append(missing, item.Key)
		}
	}
	return missing
}

func missingRequiredV2(checklist []ReadinessItem) []string {
	return missingForKeys(checklist, onboardingV2RequiredKeys)
}

func annotateChecklistDeferredV2(checklist []ReadinessItem, completedRides int) []ReadinessItem {
	requiredNow := onboardingV2RequiredKeysFor(completedRides)
	out := make([]ReadinessItem, len(checklist))
	for i, item := range checklist {
		out[i] = item
		if item.Complete {
			continue
		}
		if _, required := requiredNow[item.Key]; required {
			continue
		}
		if strings.TrimSpace(out[i].Note) != "" {
			continue
		}
		if _, ok := onboardingV2Milestone50Keys[item.Key]; ok && completedRides < onboardingV2Milestone50 {
			out[i].Note = fmt.Sprintf("Required after %d completed rides", onboardingV2Milestone50)
			continue
		}
		if _, ok := onboardingV2Milestone20Keys[item.Key]; ok && completedRides < onboardingV2Milestone20 {
			out[i].Note = fmt.Sprintf("Required after %d completed rides", onboardingV2Milestone20)
			continue
		}
		out[i].Note = "Progressive verification — complete after your first rides"
	}
	return out
}

func hasNonEmptyVehiclePhoto(urls []string) bool {
	for _, u := range urls {
		if strings.TrimSpace(u) != "" {
			return true
		}
	}
	return false
}

func nlTaxiInsuranceComplete(c *repository.DriverCompliance) bool {
	if strings.TrimSpace(c.TaxiInsuranceProvider) == "" ||
		strings.TrimSpace(c.TaxiInsurancePolicyNumber) == "" ||
		strings.TrimSpace(c.TaxiInsurancePhotoURL) == "" {
		return false
	}
	return c.TaxiInsuranceExpiry != nil
}

func missingFromChecklist(checklist []ReadinessItem) []string {
	missing := make([]string, 0, len(checklist))
	for _, item := range checklist {
		if !item.Complete {
			missing = append(missing, item.Key)
		}
	}
	return missing
}
