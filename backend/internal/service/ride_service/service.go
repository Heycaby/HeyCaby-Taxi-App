package rideservice

import (
	"context"
	"errors"
	"fmt"

	"github.com/heycaby/backend/internal/cache"
	"github.com/heycaby/backend/internal/repository"
)

// RideService handles ride request lifecycle.
type RideService struct {
	rides *repository.RideRepository
	redis *cache.RedisClient
}

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

type CreateManualRideResult struct {
	RideID string
}

var ErrRideAlreadyAccepted = errors.New("ride already accepted")

func New(rides *repository.RideRepository, redis *cache.RedisClient) *RideService {
	return &RideService{rides: rides, redis: redis}
}

// CreateRequest inserts a new ride_request row.
func (s *RideService) CreateRequest(ctx context.Context, in *repository.CreateRideInput) (*repository.RideRequest, error) {
	ride, err := s.rides.CreateRequest(ctx, in)
	if err != nil {
		return nil, fmt.Errorf("RideService.CreateRequest: %w", err)
	}
	return ride, nil
}

// GetByID fetches a ride request by ID.
func (s *RideService) GetByID(ctx context.Context, rideID string) (*repository.RideRequest, error) {
	return s.rides.GetByID(ctx, rideID)
}

// Cancel transitions a ride request to cancelled status.
func (s *RideService) Cancel(ctx context.Context, rideID string) error {
	return s.rides.UpdateStatus(ctx, rideID, "cancelled")
}

// Accept atomically locks and assigns a pending ride to a single driver.
func (s *RideService) Accept(ctx context.Context, rideID, driverID string) error {
	if s.redis == nil {
		return fmt.Errorf("RideService.Accept: redis unavailable")
	}

	locked, err := s.redis.LockRide(ctx, rideID, driverID)
	if err != nil {
		return fmt.Errorf("RideService.Accept lock ride: %w", err)
	}
	if !locked {
		return ErrRideAlreadyAccepted
	}

	if err := s.rides.AcceptPendingByDriver(ctx, rideID, driverID); err != nil {
		if errors.Is(err, repository.ErrRideAlreadyAccepted) {
			return ErrRideAlreadyAccepted
		}
		_ = s.redis.UnlockRide(ctx, rideID)
		return fmt.Errorf("RideService.Accept assign pending ride: %w", err)
	}
	return nil
}

// Start transitions a ride request to in_progress.
func (s *RideService) Start(ctx context.Context, rideID string) error {
	return s.rides.UpdateStatus(ctx, rideID, "in_progress")
}

// Complete transitions a ride request to completed.
func (s *RideService) Complete(ctx context.Context, rideID string) error {
	return s.rides.UpdateStatus(ctx, rideID, "completed")
}

func (s *RideService) CreateManualRide(ctx context.Context, in CreateManualRideInput) (*CreateManualRideResult, error) {
	if in.DriverID == "" {
		return nil, fmt.Errorf("CreateManualRide: missing driver id")
	}
	if in.CountryCode == "" {
		return nil, fmt.Errorf("CreateManualRide: missing country code")
	}
	if in.DropoffAddress == "" {
		return nil, fmt.Errorf("CreateManualRide: missing dropoff address")
	}
	if in.FareCents <= 0 || in.FareCents > 200000 {
		return nil, fmt.Errorf("CreateManualRide: fare out of range")
	}
	switch in.PaymentMethod {
	case "cash", "card", "tikkie":
	default:
		return nil, fmt.Errorf("CreateManualRide: invalid payment method")
	}
	currency := in.Currency
	if currency == "" {
		currency = "EUR"
	}
	rideID, err := s.rides.CreateManualRide(ctx, &repository.CreateManualRideInput{
		DriverID:       in.DriverID,
		CountryCode:    in.CountryCode,
		Currency:       currency,
		PickupAddress:  in.PickupAddress,
		DropoffAddress: in.DropoffAddress,
		FareCents:      in.FareCents,
		PaymentMethod:  in.PaymentMethod,
		PassengerName:  in.PassengerName,
		PickupLat:      in.PickupLat,
		PickupLng:      in.PickupLng,
		DropoffLat:     in.DropoffLat,
		DropoffLng:     in.DropoffLng,
	})
	if err != nil {
		return nil, fmt.Errorf("CreateManualRide: %w", err)
	}
	return &CreateManualRideResult{RideID: rideID}, nil
}
