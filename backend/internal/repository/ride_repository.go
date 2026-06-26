package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// RideRequest represents a ride_requests row.
type RideRequest struct {
	ID          string
	RiderID     string
	DriverID    string
	CountryCode string
	Currency    string
	Status      string
	PickupLat   float64
	PickupLng   float64
	DestLat     float64
	DestLng     float64
	CreatedAt   time.Time
}

// CreateRideInput holds fields to insert for a new ride request.
type CreateRideInput struct {
	RiderID          string
	RiderIdentityID  string
	PickupLat        float64
	PickupLng        float64
	PickupAddress    string
	DestLat          float64
	DestLng          float64
	DestAddress      string
	CountryCode      string
	Currency         string
	VehicleCategory  string
	PaymentMethod    string
	SelectedDriverID string
}

// CreateManualRideInput captures a manually recorded street pickup ride.
type CreateManualRideInput struct {
	DriverID       string
	CountryCode    string
	Currency       string
	PickupAddress  string
	DropoffAddress string
	FareCents      int
	PaymentMethod  string
	PassengerName  string
	PickupLat      *float64
	PickupLng      *float64
	DropoffLat     *float64
	DropoffLng     *float64
}

// RideRepository handles ride_requests and rides table operations.
type RideRepository struct {
	client *SupabaseClient
}

var ErrRideAlreadyAccepted = errors.New("ride already accepted")

func NewRideRepository(client *SupabaseClient) *RideRepository {
	return &RideRepository{client: client}
}

// CreateRequest inserts a new ride_request row.
func (r *RideRepository) CreateRequest(ctx context.Context, in *CreateRideInput) (*RideRequest, error) {
	body := map[string]any{
		"rider_id":             in.RiderID,
		"rider_identity_id":    in.RiderIdentityID,
		"pickup_location":      fmt.Sprintf("POINT(%f %f)", in.PickupLng, in.PickupLat),
		"pickup_address":       in.PickupAddress,
		"destination_location": fmt.Sprintf("POINT(%f %f)", in.DestLng, in.DestLat),
		"destination_address":  in.DestAddress,
		"country_code":         in.CountryCode,
		"currency":             in.Currency,
		"vehicle_category":     in.VehicleCategory,
		"payment_method":       in.PaymentMethod,
		"status":               "searching",
		"created_at":           time.Now().UTC().Format(time.RFC3339),
	}
	if in.SelectedDriverID != "" {
		body["driver_id"] = in.SelectedDriverID
	}

	var rows []struct {
		ID          string `json:"id"`
		Status      string `json:"status"`
		CountryCode string `json:"country_code"`
		Currency    string `json:"currency"`
	}
	if err := r.client.post(ctx, "/rest/v1/ride_requests?select=id,status,country_code,currency", body, &rows); err != nil {
		return nil, fmt.Errorf("CreateRequest: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("CreateRequest: no row returned")
	}
	return &RideRequest{
		ID:          rows[0].ID,
		Status:      rows[0].Status,
		CountryCode: rows[0].CountryCode,
		Currency:    rows[0].Currency,
	}, nil
}

// UpdateStatus transitions ride_request to a new status.
func (r *RideRepository) UpdateStatus(ctx context.Context, rideID, status string) error {
	body := map[string]any{
		"status":     status,
		"updated_at": time.Now().UTC().Format(time.RFC3339),
	}
	return r.client.patch(ctx, "/rest/v1/ride_requests?id=eq."+rideID, body)
}

// AcceptPendingByDriver assigns a pending ride to a single driver.
// It succeeds only when the ride is still pending.
func (r *RideRepository) AcceptPendingByDriver(ctx context.Context, rideID, driverID string) error {
	body := map[string]any{
		"status":      "accepted",
		"driver_id":   driverID,
		"accepted_at": time.Now().UTC().Format(time.RFC3339),
		"updated_at":  time.Now().UTC().Format(time.RFC3339),
	}
	b, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("AcceptPendingByDriver marshal body: %w", err)
	}

	path := "/rest/v1/ride_requests?id=eq." + rideID + "&status=in.(pending,searching)&select=id"
	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, r.client.baseURL+path, bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("AcceptPendingByDriver build request: %w", err)
	}
	r.client.setHeaders(req)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.client.http.Do(req)
	if err != nil {
		return fmt.Errorf("AcceptPendingByDriver PATCH: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		raw, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("AcceptPendingByDriver PATCH: status %d: %s", resp.StatusCode, string(raw))
	}

	var rows []struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&rows); err != nil {
		return fmt.Errorf("AcceptPendingByDriver decode response: %w", err)
	}
	if len(rows) == 0 {
		return ErrRideAlreadyAccepted
	}
	return nil
}

// GetByID fetches a single ride_request row.
func (r *RideRepository) GetByID(ctx context.Context, rideID string) (*RideRequest, error) {
	params := url.Values{}
	params.Set("select", "id,rider_id,driver_id,country_code,currency,status,created_at")
	params.Set("id", "eq."+rideID)
	params.Set("limit", "1")

	var rows []struct {
		ID          string `json:"id"`
		RiderID     string `json:"rider_id"`
		DriverID    string `json:"driver_id"`
		CountryCode string `json:"country_code"`
		Currency    string `json:"currency"`
		Status      string `json:"status"`
		CreatedAt   string `json:"created_at"`
	}
	if err := r.client.get(ctx, "/rest/v1/ride_requests", params, &rows); err != nil {
		return nil, fmt.Errorf("GetByID: %w", err)
	}
	if len(rows) == 0 {
		return nil, fmt.Errorf("ride request %s not found", rideID)
	}
	row := rows[0]
	t, _ := time.Parse(time.RFC3339, row.CreatedAt)
	return &RideRequest{
		ID:          row.ID,
		RiderID:     row.RiderID,
		DriverID:    row.DriverID,
		CountryCode: row.CountryCode,
		Currency:    row.Currency,
		Status:      row.Status,
		CreatedAt:   t,
	}, nil
}

// CreateManualRide inserts a completed manual ride in ride_requests for bookkeeping.
func (r *RideRepository) CreateManualRide(ctx context.Context, in *CreateManualRideInput) (string, error) {
	body := map[string]any{
		"driver_id":             in.DriverID,
		"status":                "completed",
		"country_code":          in.CountryCode,
		"currency":              in.Currency,
		"pickup_address":        in.PickupAddress,
		"destination_address":   in.DropoffAddress,
		"manual_entry":          true,
		"manual_passenger_name": in.PassengerName,
		"manual_fare_cents":     in.FareCents,
		"manual_payment_method": in.PaymentMethod,
		"payment_method":        in.PaymentMethod,
		"driver_earnings_cents": in.FareCents,
		"platform_fee_cents":    0,
		"created_at":            time.Now().UTC().Format(time.RFC3339),
		"updated_at":            time.Now().UTC().Format(time.RFC3339),
	}
	if in.PickupLat != nil && in.PickupLng != nil {
		body["pickup_location"] = fmt.Sprintf("POINT(%f %f)", *in.PickupLng, *in.PickupLat)
	}
	if in.DropoffLat != nil && in.DropoffLng != nil {
		body["destination_location"] = fmt.Sprintf("POINT(%f %f)", *in.DropoffLng, *in.DropoffLat)
	}

	var rows []struct {
		ID string `json:"id"`
	}
	if err := r.client.post(ctx, "/rest/v1/ride_requests?select=id", body, &rows); err != nil {
		return "", fmt.Errorf("CreateManualRide: %w", err)
	}
	if len(rows) == 0 || rows[0].ID == "" {
		return "", fmt.Errorf("CreateManualRide: no id returned")
	}
	return rows[0].ID, nil
}
