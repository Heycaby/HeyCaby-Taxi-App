package handler

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	regionmw "github.com/heycaby/backend/internal/middleware/region"
	matchingservice "github.com/heycaby/backend/internal/service/matching_service"
)

// RiderHandler exposes rider-facing endpoints.
type RiderHandler struct {
	matching *matchingservice.MatchingService
}

func NewRiderHandler(matching *matchingservice.MatchingService) *RiderHandler {
	return &RiderHandler{matching: matching}
}

// GET /api/v1/rider/nearby-supply?lat=52.37&lng=4.89
func (h *RiderHandler) NearbySupply(c *fiber.Ctx) error {
	lat, err1 := strconv.ParseFloat(c.Query("lat"), 64)
	lng, err2 := strconv.ParseFloat(c.Query("lng"), 64)
	if err1 != nil || err2 != nil {
		return fiber.NewError(fiber.StatusBadRequest, "lat and lng query params are required")
	}
	var riderRadiusKm *float64
	if raw := c.Query("rider_radius_km"); raw != "" {
		v, err := strconv.ParseFloat(raw, 64)
		if err != nil || v <= 0 {
			return fiber.NewError(fiber.StatusBadRequest, "rider_radius_km must be a positive number")
		}
		riderRadiusKm = &v
	}

	countryCode := regionmw.GetCountryCode(c)
	provinceCode := regionmw.GetProvinceCode(c)
	launchAllowed := regionmw.IsLaunchAllowed(c)
	launchReason := regionmw.GetLaunchReason(c)

	drivers, err := h.matching.NearbyDrivers(c.Context(), countryCode, lat, lng, riderRadiusKm)
	if err != nil {
		return err
	}

	type driverOut struct {
		ID                      string  `json:"id"`
		DriverID                string  `json:"driver_id"`
		FullName                string  `json:"full_name"`
		Name                    string  `json:"name"`
		PhotoURL                string  `json:"photo_url,omitempty"`
		Rating                  float64 `json:"rating"`
		VehicleCategory         string  `json:"vehicle_category"`
		DistanceKm              float64 `json:"distance_km"`
		EstimatedFare           float64 `json:"estimated_fare"`
		Currency                string  `json:"currency"`
		BaseFare                float64 `json:"base_fare"`
		PerKmRate               float64 `json:"per_km_rate"`
		ActiveReturnDiscountPct float64 `json:"active_return_discount_pct"`
	}
	out := make([]driverOut, 0, len(drivers))
	for _, d := range drivers {
		estimatedFare := d.BaseFare + (2 * d.PerKmRate)
		out = append(out, driverOut{
			ID:                      d.ID,
			DriverID:                d.ID,
			FullName:                d.FullName,
			Name:                    d.FullName,
			PhotoURL:                d.ProfilePhotoURL,
			Rating:                  d.Rating,
			VehicleCategory:         d.VehicleCategory,
			DistanceKm:              0,
			EstimatedFare:           estimatedFare,
			Currency:                "EUR",
			BaseFare:                d.BaseFare,
			PerKmRate:               d.PerKmRate,
			ActiveReturnDiscountPct: d.ActiveReturnDiscountPct,
		})
	}
	return ok(c, fiber.Map{
		"drivers":        out,
		"count":          len(out),
		"country_code":   countryCode,
		"province_code":  provinceCode,
		"launch_allowed": launchAllowed,
		"launch_reason":  launchReason,
	})
}
