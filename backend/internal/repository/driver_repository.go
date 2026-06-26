package repository

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"
)

// Driver is the subset of drivers table fields used by the Go backend.
type Driver struct {
	ID                      string
	FullName                string
	ProfilePhotoURL         string
	Rating                  float64
	BaseFare                float64
	PerKmRate               float64
	VehicleCategory         string
	Status                  string
	CountryCode             string
	ActiveReturnDiscountPct float64
	PickupDistanceMaxKm     float64
}

// DriverCompliance holds fields needed to evaluate driver readiness to go online.
type DriverCompliance struct {
	ID                        string
	CountryCode               string
	ProfilePhotoURL           string
	KvkNumber                 string
	KvkAddress                string
	ChauffeurspasNumber       string
	ChauffeurspasExpiry       *time.Time
	TaxiInsuranceProvider     string
	TaxiInsurancePolicyNumber string
	TaxiInsurancePhotoURL     string
	TaxiInsuranceExpiry       *time.Time
	VehiclePlate              string
	TermsAcceptedAt           *time.Time
	IndemnificationReadAt     *time.Time
	IndemnificationQuizPassed bool
	RijbewijsVerified         bool
	VehiclePhotoURLs          []string
	IsReviewAccount           bool
}

type DriverContact struct {
	DriverID string
	Email    string
	FullName string
}

type DriverBillingProfile struct {
	DriverID               string
	CountryCode            string
	IsFoundingDriver       bool
	FoundingNumber         int
	TotalEarningsCents     int
	SubscriptionExpiresAt  *time.Time
	WeeklyRateEuros        float64
	BillingStartsAfterEuro float64
	MollieCustomerID       string
	MollieSubscriptionID   string
}

type DriverPaymentEvent struct {
	ID              string         `json:"id"`
	DriverID        string         `json:"driver_id,omitempty"`
	AmountCents     int            `json:"amount_cents"`
	Currency        string         `json:"currency"`
	Status          string         `json:"status"`
	Provider        string         `json:"provider,omitempty"`
	MolliePaymentID string         `json:"mollie_payment_id,omitempty"`
	ErrorMessage    string         `json:"error_message,omitempty"`
	Metadata        map[string]any `json:"metadata,omitempty"`
	CreatedAt       time.Time      `json:"created_at"`
}

type DriverEmailEvent struct {
	ID                string
	DriverID          string
	EventType         string
	TemplateID        string
	IdempotencyKey    string
	RecipientEmail    string
	Payload           map[string]any
	Status            string
	ProviderMessageID string
	AttemptCount      int
	LastError         string
}

// PendingRideRequest is a lightweight row used by heartbeat to return
// outstanding ride requests already targeted to this driver.
type PendingRideRequest struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
}

// DriverRepository handles all driver-related DB queries.
type DriverRepository struct {
	client *SupabaseClient
}

func NewDriverRepository(client *SupabaseClient) *DriverRepository {
	return &DriverRepository{client: client}
}

// GetByIDs fetches driver profiles + pricing for a list of IDs, scoped to countryCode.
// Used by the matching service after Redis GEO returns nearby driver IDs.
func (r *DriverRepository) GetByIDs(ctx context.Context, ids []string, countryCode string) ([]Driver, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	params := url.Values{}
	params.Set("select", "id,full_name,profile_photo_url,avg_rating,base_fare,per_km_rate,vehicle_category,status,country_code,active_return_discount_pct,pickup_distance_max_km")
	params.Set("id", fmt.Sprintf("in.(%s)", strings.Join(ids, ",")))
	params.Set("country_code", "eq."+countryCode)
	params.Set("status", "in.(available,on_ride)")

	var rows []struct {
		ID                      string  `json:"id"`
		FullName                string  `json:"full_name"`
		ProfilePhotoURL         string  `json:"profile_photo_url"`
		AvgRating               float64 `json:"avg_rating"`
		BaseFare                float64 `json:"base_fare"`
		PerKmRate               float64 `json:"per_km_rate"`
		VehicleCategory         string  `json:"vehicle_category"`
		Status                  string  `json:"status"`
		CountryCode             string  `json:"country_code"`
		ActiveReturnDiscountPct float64 `json:"active_return_discount_pct"`
		PickupDistanceMaxKm     float64 `json:"pickup_distance_max_km"`
	}

	if err := r.client.get(ctx, "/rest/v1/drivers", params, &rows); err != nil {
		return nil, fmt.Errorf("GetByIDs: %w", err)
	}

	drivers := make([]Driver, 0, len(rows))
	for _, row := range rows {
		drivers = append(drivers, Driver{
			ID:                      row.ID,
			FullName:                row.FullName,
			ProfilePhotoURL:         row.ProfilePhotoURL,
			Rating:                  row.AvgRating,
			BaseFare:                row.BaseFare,
			PerKmRate:               row.PerKmRate,
			VehicleCategory:         row.VehicleCategory,
			Status:                  row.Status,
			CountryCode:             row.CountryCode,
			ActiveReturnDiscountPct: row.ActiveReturnDiscountPct,
			PickupDistanceMaxKm:     row.PickupDistanceMaxKm,
		})
	}
	return drivers, nil
}

// GetCompliance fetches all compliance fields for a driver readiness check.
func (r *DriverRepository) GetCompliance(ctx context.Context, driverID string) (*DriverCompliance, error) {
	params := url.Values{}
	params.Set("select", "id,country_code,profile_photo_url,vehicle_photo_urls,kvk_number,kvk_address,chauffeurspas_number,chauffeurspas_expiry,taxi_insurance_provider,taxi_insurance_policy_number,taxi_insurance_photo_url,taxi_insurance_expiry,vehicle_plate,terms_accepted_at,indemnification_read_at,indemnification_quiz_passed,rijbewijs_verified")
	params.Set("id", "eq."+driverID)
	params.Set("limit", "1")

	var rows []struct {
		ID                        string   `json:"id"`
		CountryCode               string   `json:"country_code"`
		ProfilePhotoURL           string   `json:"profile_photo_url"`
		VehiclePhotoURLs          []string `json:"vehicle_photo_urls"`
		KvkNumber                 string   `json:"kvk_number"`
		KvkAddress                string   `json:"kvk_address"`
		ChauffeurspasNumber       string   `json:"chauffeurspas_number"`
		ChauffeurspasExpiry       *string  `json:"chauffeurspas_expiry"`
		TaxiInsuranceProvider     string   `json:"taxi_insurance_provider"`
		TaxiInsurancePolicyNumber string   `json:"taxi_insurance_policy_number"`
		TaxiInsurancePhotoURL     string   `json:"taxi_insurance_photo_url"`
		TaxiInsuranceExpiry       *string  `json:"taxi_insurance_expiry"`
		VehiclePlate              string   `json:"vehicle_plate"`
		TermsAcceptedAt           *string  `json:"terms_accepted_at"`
		IndemnificationReadAt     *string  `json:"indemnification_read_at"`
		IndemnificationQuizPassed bool     `json:"indemnification_quiz_passed"`
		RijbewijsVerified         bool     `json:"rijbewijs_verified"`
	}

	if err := r.client.get(ctx, "/rest/v1/drivers", params, &rows); err != nil {
		return nil, fmt.Errorf("GetCompliance: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("driver %s not found", driverID)
	}

	row := rows[0]
	c := &DriverCompliance{
		ID:                        row.ID,
		CountryCode:               row.CountryCode,
		ProfilePhotoURL:           row.ProfilePhotoURL,
		VehiclePhotoURLs:          row.VehiclePhotoURLs,
		KvkNumber:                 row.KvkNumber,
		KvkAddress:                row.KvkAddress,
		ChauffeurspasNumber:       row.ChauffeurspasNumber,
		TaxiInsuranceProvider:     row.TaxiInsuranceProvider,
		TaxiInsurancePolicyNumber: row.TaxiInsurancePolicyNumber,
		TaxiInsurancePhotoURL:     row.TaxiInsurancePhotoURL,
		VehiclePlate:              row.VehiclePlate,
		IndemnificationQuizPassed: row.IndemnificationQuizPassed,
		RijbewijsVerified:         row.RijbewijsVerified,
	}
	if row.ChauffeurspasExpiry != nil {
		t, _ := time.Parse(time.RFC3339, *row.ChauffeurspasExpiry)
		c.ChauffeurspasExpiry = &t
	}
	if row.TaxiInsuranceExpiry != nil {
		t, _ := time.Parse(time.RFC3339, *row.TaxiInsuranceExpiry)
		c.TaxiInsuranceExpiry = &t
	}
	if row.TermsAcceptedAt != nil {
		t, err := time.Parse(time.RFC3339, *row.TermsAcceptedAt)
		if err == nil {
			c.TermsAcceptedAt = &t
		}
	}
	if row.IndemnificationReadAt != nil {
		t, _ := time.Parse(time.RFC3339, *row.IndemnificationReadAt)
		c.IndemnificationReadAt = &t
	}
	return c, nil
}

// UpsertLocation writes driver GPS to driver_locations table (async audit trail).
func (r *DriverRepository) UpsertLocation(ctx context.Context, driverID, countryCode string, lat, lng float64) error {
	body := map[string]any{
		"driver_id":    driverID,
		"latitude":     lat,
		"longitude":    lng,
		"country_code": countryCode,
		"updated_at":   time.Now().UTC().Format(time.RFC3339),
	}
	return r.client.post(ctx, "/rest/v1/driver_locations?on_conflict=driver_id", body, nil)
}

// SetStatus updates driver.status column (online/offline/on_break).
func (r *DriverRepository) SetStatus(ctx context.Context, driverID, status string) error {
	body := map[string]any{"status": status}
	return r.client.patch(ctx, "/rest/v1/drivers?id=eq."+driverID, body)
}

// GetAvailableInCountry returns available/on_ride drivers for a country.
// Used as Supabase fallback when Redis GEO is disabled.
func (r *DriverRepository) GetAvailableInCountry(ctx context.Context, countryCode string) ([]Driver, error) {
	params := url.Values{}
	params.Set("select", "id,full_name,profile_photo_url,avg_rating,base_fare,per_km_rate,vehicle_category,status,country_code,active_return_discount_pct,pickup_distance_max_km")
	params.Set("country_code", "eq."+countryCode)
	params.Set("status", "in.(available,on_ride)")
	params.Set("limit", "50")

	var rows []struct {
		ID                      string  `json:"id"`
		FullName                string  `json:"full_name"`
		ProfilePhotoURL         string  `json:"profile_photo_url"`
		AvgRating               float64 `json:"avg_rating"`
		BaseFare                float64 `json:"base_fare"`
		PerKmRate               float64 `json:"per_km_rate"`
		VehicleCategory         string  `json:"vehicle_category"`
		Status                  string  `json:"status"`
		CountryCode             string  `json:"country_code"`
		ActiveReturnDiscountPct float64 `json:"active_return_discount_pct"`
		PickupDistanceMaxKm     float64 `json:"pickup_distance_max_km"`
	}

	if err := r.client.get(ctx, "/rest/v1/drivers", params, &rows); err != nil {
		return nil, fmt.Errorf("GetAvailableInCountry: %w", err)
	}

	drivers := make([]Driver, 0, len(rows))
	for _, row := range rows {
		drivers = append(drivers, Driver{
			ID:                      row.ID,
			FullName:                row.FullName,
			ProfilePhotoURL:         row.ProfilePhotoURL,
			Rating:                  row.AvgRating,
			BaseFare:                row.BaseFare,
			PerKmRate:               row.PerKmRate,
			VehicleCategory:         row.VehicleCategory,
			Status:                  row.Status,
			CountryCode:             row.CountryCode,
			ActiveReturnDiscountPct: row.ActiveReturnDiscountPct,
			PickupDistanceMaxKm:     row.PickupDistanceMaxKm,
		})
	}
	return drivers, nil
}

// GetPendingRideRequestsForDriver returns newest ride requests that are still
// actionable for the driver. This is used by heartbeat to keep the app in sync.
func (r *DriverRepository) GetPendingRideRequestsForDriver(
	ctx context.Context,
	driverID string,
	countryCode string,
	limit int,
) ([]PendingRideRequest, error) {
	if limit <= 0 {
		limit = 5
	}

	params := url.Values{}
	params.Set("select", "id,status,created_at")
	params.Set("driver_id", "eq."+driverID)
	params.Set("country_code", "eq."+countryCode)
	params.Set("status", "in.(searching,assigned,accepted)")
	params.Set("order", "created_at.desc")
	params.Set("limit", fmt.Sprintf("%d", limit))

	var rows []PendingRideRequest
	if err := r.client.get(ctx, "/rest/v1/ride_requests", params, &rows); err != nil {
		return nil, fmt.Errorf("GetPendingRideRequestsForDriver: %w", err)
	}
	return rows, nil
}

// CountCompletedRides returns lifetime completed ride_requests for a driver.
func (r *DriverRepository) CountCompletedRides(ctx context.Context, driverID string) (int, error) {
	var count int
	if err := r.client.post(ctx, "/rest/v1/rpc/fn_driver_lifetime_completed_rides", map[string]any{
		"p_driver_id": driverID,
	}, &count); err != nil {
		return 0, fmt.Errorf("CountCompletedRides: %w", err)
	}
	return count, nil
}

func (r *DriverRepository) GetContact(ctx context.Context, driverID string) (*DriverContact, error) {
	params := url.Values{}
	params.Set("select", "id,email,full_name")
	params.Set("id", "eq."+driverID)
	params.Set("limit", "1")

	var rows []struct {
		ID       string `json:"id"`
		Email    string `json:"email"`
		FullName string `json:"full_name"`
	}
	if err := r.client.get(ctx, "/rest/v1/drivers", params, &rows); err != nil {
		return nil, fmt.Errorf("GetContact: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("GetContact: driver %s not found", driverID)
	}
	if strings.TrimSpace(rows[0].Email) == "" {
		return nil, fmt.Errorf("GetContact: driver %s has no email", driverID)
	}
	return &DriverContact{
		DriverID: rows[0].ID,
		Email:    rows[0].Email,
		FullName: rows[0].FullName,
	}, nil
}

func (r *DriverRepository) FindEmailEventByIdempotency(ctx context.Context, key string) (*DriverEmailEvent, error) {
	params := url.Values{}
	params.Set("select", "id,driver_id,event_type,template_id,idempotency_key,recipient_email,status,provider_message_id,attempt_count,last_error")
	params.Set("idempotency_key", "eq."+key)
	params.Set("limit", "1")

	var rows []struct {
		ID                string `json:"id"`
		DriverID          string `json:"driver_id"`
		EventType         string `json:"event_type"`
		TemplateID        string `json:"template_id"`
		IdempotencyKey    string `json:"idempotency_key"`
		RecipientEmail    string `json:"recipient_email"`
		Status            string `json:"status"`
		ProviderMessageID string `json:"provider_message_id"`
		AttemptCount      int    `json:"attempt_count"`
		LastError         string `json:"last_error"`
	}
	if err := r.client.get(ctx, "/rest/v1/driver_email_events", params, &rows); err != nil {
		return nil, fmt.Errorf("FindEmailEventByIdempotency: %w", err)
	}
	if len(rows) == 0 {
		return nil, nil
	}
	row := rows[0]
	return &DriverEmailEvent{
		ID:                row.ID,
		DriverID:          row.DriverID,
		EventType:         row.EventType,
		TemplateID:        row.TemplateID,
		IdempotencyKey:    row.IdempotencyKey,
		RecipientEmail:    row.RecipientEmail,
		Status:            row.Status,
		ProviderMessageID: row.ProviderMessageID,
		AttemptCount:      row.AttemptCount,
		LastError:         row.LastError,
	}, nil
}

func (r *DriverRepository) CreateEmailEvent(ctx context.Context, event *DriverEmailEvent) (*DriverEmailEvent, error) {
	body := map[string]any{
		"driver_id":           event.DriverID,
		"event_type":          event.EventType,
		"template_id":         event.TemplateID,
		"idempotency_key":     event.IdempotencyKey,
		"recipient_email":     event.RecipientEmail,
		"payload":             event.Payload,
		"status":              event.Status,
		"attempt_count":       event.AttemptCount,
		"last_error":          event.LastError,
		"provider_message_id": event.ProviderMessageID,
	}

	var rows []struct {
		ID string `json:"id"`
	}
	if err := r.client.post(ctx, "/rest/v1/driver_email_events?select=id", body, &rows); err != nil {
		return nil, fmt.Errorf("CreateEmailEvent: %w", err)
	}
	if len(rows) == 0 || rows[0].ID == "" {
		return nil, fmt.Errorf("CreateEmailEvent: no row returned")
	}
	out := *event
	out.ID = rows[0].ID
	return &out, nil
}

func (r *DriverRepository) UpdateEmailEventStatus(ctx context.Context, eventID string, status string, attemptCount int, providerMessageID, lastError string) error {
	body := map[string]any{
		"status":              status,
		"attempt_count":       attemptCount,
		"provider_message_id": providerMessageID,
		"last_error":          lastError,
		"updated_at":          time.Now().UTC().Format(time.RFC3339),
	}
	return r.client.patch(ctx, "/rest/v1/driver_email_events?id=eq."+eventID, body)
}

func (r *DriverRepository) GetBillingProfile(ctx context.Context, driverID string) (*DriverBillingProfile, error) {
	params := url.Values{}
	params.Set("select", "id,country_code,is_founding_driver,founding_number,total_earnings_cents,subscription_expires_at,weekly_rate_euros,billing_starts_after_euros,mollie_customer_id,mollie_subscription_id")
	params.Set("id", "eq."+driverID)
	params.Set("limit", "1")

	var rows []struct {
		ID                     string   `json:"id"`
		CountryCode            string   `json:"country_code"`
		IsFoundingDriver       bool     `json:"is_founding_driver"`
		FoundingNumber         *int     `json:"founding_number"`
		TotalEarningsCents     *int     `json:"total_earnings_cents"`
		SubscriptionExpiresAt  *string  `json:"subscription_expires_at"`
		WeeklyRateEuros        *float64 `json:"weekly_rate_euros"`
		BillingStartsAfterEuro *float64 `json:"billing_starts_after_euros"`
		MollieCustomerID       string   `json:"mollie_customer_id"`
		MollieSubscriptionID   string   `json:"mollie_subscription_id"`
	}
	if err := r.client.get(ctx, "/rest/v1/drivers", params, &rows); err != nil {
		return nil, fmt.Errorf("GetBillingProfile: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("GetBillingProfile: driver %s not found", driverID)
	}
	row := rows[0]
	out := &DriverBillingProfile{
		DriverID:             row.ID,
		CountryCode:          row.CountryCode,
		IsFoundingDriver:     row.IsFoundingDriver,
		MollieCustomerID:     row.MollieCustomerID,
		MollieSubscriptionID: row.MollieSubscriptionID,
	}
	if row.FoundingNumber != nil {
		out.FoundingNumber = *row.FoundingNumber
	}
	if row.TotalEarningsCents != nil {
		out.TotalEarningsCents = *row.TotalEarningsCents
	}
	if row.WeeklyRateEuros != nil {
		out.WeeklyRateEuros = *row.WeeklyRateEuros
	}
	if row.BillingStartsAfterEuro != nil {
		out.BillingStartsAfterEuro = *row.BillingStartsAfterEuro
	}
	if row.SubscriptionExpiresAt != nil {
		t, err := time.Parse(time.RFC3339, *row.SubscriptionExpiresAt)
		if err == nil {
			out.SubscriptionExpiresAt = &t
		}
	}
	return out, nil
}

func (r *DriverRepository) SetSubscriptionExpiry(ctx context.Context, driverID string, expiresAt time.Time) error {
	body := map[string]any{
		"subscription_expires_at": expiresAt.UTC().Format(time.RFC3339),
		"subscription_active":     true,
		"updated_at":              time.Now().UTC().Format(time.RFC3339),
	}
	return r.client.patch(ctx, "/rest/v1/drivers?id=eq."+driverID, body)
}

func (r *DriverRepository) CancelSubscription(ctx context.Context, driverID string) error {
	body := map[string]any{
		"subscription_active": false,
		"updated_at":          time.Now().UTC().Format(time.RFC3339),
	}
	return r.client.patch(ctx, "/rest/v1/drivers?id=eq."+driverID, body)
}

func (r *DriverRepository) InsertDriverPaymentEvent(ctx context.Context, in DriverPaymentEvent) (*DriverPaymentEvent, error) {
	if in.Provider == "" {
		in.Provider = "mollie"
	}
	if in.Currency == "" {
		in.Currency = "EUR"
	}
	if in.Metadata == nil {
		in.Metadata = map[string]any{}
	}
	body := map[string]any{
		"driver_id":         in.DriverID,
		"amount_cents":      in.AmountCents,
		"currency":          in.Currency,
		"status":            in.Status,
		"provider":          in.Provider,
		"mollie_payment_id": in.MolliePaymentID,
		"error_message":     in.ErrorMessage,
		"metadata":          in.Metadata,
		"country_code":      "NL",
	}

	var rows []struct {
		ID        string         `json:"id"`
		CreatedAt string         `json:"created_at"`
		Metadata  map[string]any `json:"metadata"`
	}
	if err := r.client.post(ctx, "/rest/v1/driver_payment_events?select=id,created_at,metadata", body, &rows); err != nil {
		return nil, fmt.Errorf("InsertDriverPaymentEvent: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("InsertDriverPaymentEvent: no row returned")
	}
	out := in
	out.ID = rows[0].ID
	if rows[0].CreatedAt != "" {
		if t, err := time.Parse(time.RFC3339, rows[0].CreatedAt); err == nil {
			out.CreatedAt = t
		}
	}
	if rows[0].Metadata != nil {
		out.Metadata = rows[0].Metadata
	}
	return &out, nil
}

func (r *DriverRepository) UpdateDriverPaymentEvent(ctx context.Context, id string, status string, errorMessage string, metadata map[string]any) error {
	body := map[string]any{
		"status":        status,
		"error_message": errorMessage,
	}
	if metadata != nil {
		body["metadata"] = metadata
	}
	return r.client.patch(ctx, "/rest/v1/driver_payment_events?id=eq."+id, body)
}

func (r *DriverRepository) ListDriverPaymentEvents(ctx context.Context, driverID string, limit int) ([]DriverPaymentEvent, error) {
	if limit <= 0 {
		limit = 50
	}
	params := url.Values{}
	params.Set("select", "id,driver_id,amount_cents,currency,status,provider,mollie_payment_id,error_message,metadata,created_at")
	params.Set("driver_id", "eq."+driverID)
	params.Set("order", "created_at.desc")
	params.Set("limit", fmt.Sprintf("%d", limit))
	var rows []struct {
		ID              string         `json:"id"`
		DriverID        string         `json:"driver_id"`
		AmountCents     int            `json:"amount_cents"`
		Currency        string         `json:"currency"`
		Status          string         `json:"status"`
		Provider        string         `json:"provider"`
		MolliePaymentID string         `json:"mollie_payment_id"`
		ErrorMessage    string         `json:"error_message"`
		Metadata        map[string]any `json:"metadata"`
		CreatedAt       string         `json:"created_at"`
	}
	if err := r.client.get(ctx, "/rest/v1/driver_payment_events", params, &rows); err != nil {
		return nil, fmt.Errorf("ListDriverPaymentEvents: %w", err)
	}
	out := make([]DriverPaymentEvent, 0, len(rows))
	for _, row := range rows {
		item := DriverPaymentEvent{
			ID:              row.ID,
			DriverID:        row.DriverID,
			AmountCents:     row.AmountCents,
			Currency:        row.Currency,
			Status:          row.Status,
			Provider:        row.Provider,
			MolliePaymentID: row.MolliePaymentID,
			ErrorMessage:    row.ErrorMessage,
			Metadata:        row.Metadata,
		}
		if t, err := time.Parse(time.RFC3339, row.CreatedAt); err == nil {
			item.CreatedAt = t
		}
		out = append(out, item)
	}
	return out, nil
}
