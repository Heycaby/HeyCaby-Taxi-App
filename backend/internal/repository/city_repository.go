package repository

import (
	"context"
	"fmt"
	"net/url"
)

// CityRepository resolves city metadata used by middleware and services.
type CityRepository struct {
	client *SupabaseClient
}

type CityMeta struct {
	CountryCode  string
	ProvinceCode string
	IsActive     bool
}

func NewCityRepository(client *SupabaseClient) *CityRepository {
	return &CityRepository{client: client}
}

// GetCountryCodeByCityID returns the country code for a city UUID.
func (r *CityRepository) GetCountryCodeByCityID(ctx context.Context, cityID string) (string, error) {
	countryCode, _, err := r.GetCountryProvinceByCityID(ctx, cityID)
	return countryCode, err
}

// GetCountryProvinceByCityID returns country and province for a city UUID.
// Province is optional and may be empty for older rows.
func (r *CityRepository) GetCountryProvinceByCityID(ctx context.Context, cityID string) (string, string, error) {
	countryCode, provinceCode, _, err := r.GetCityRegionByID(ctx, cityID)
	return countryCode, provinceCode, err
}

// GetCityMetaByID returns country/province and city activation state.
func (r *CityRepository) GetCityMetaByID(ctx context.Context, cityID string) (*CityMeta, error) {
	countryCode, provinceCode, isActive, err := r.GetCityRegionByID(ctx, cityID)
	if err != nil {
		return nil, err
	}
	if countryCode == "" {
		return nil, nil
	}
	return &CityMeta{
		CountryCode:  countryCode,
		ProvinceCode: provinceCode,
		IsActive:     isActive,
	}, nil
}

// GetCityRegionByID returns country/province plus city is_active flag.
func (r *CityRepository) GetCityRegionByID(ctx context.Context, cityID string) (string, string, bool, error) {
	params := url.Values{}
	params.Set("select", "country_code,province_code,is_active")
	params.Set("id", "eq."+cityID)
	params.Set("limit", "1")

	var rows []struct {
		CountryCode  string `json:"country_code"`
		ProvinceCode string `json:"province_code"`
		IsActive     bool   `json:"is_active"`
	}
	if err := r.client.get(ctx, "/rest/v1/cities", params, &rows); err != nil {
		return "", "", false, fmt.Errorf("GetCityRegionByID: %w", err)
	}
	if len(rows) == 0 {
		return "", "", false, nil
	}
	return rows[0].CountryCode, rows[0].ProvinceCode, rows[0].IsActive, nil
}

// IsLaunchRegionActive returns province rollout activity.
// bool return order: (isActive, found, error).
func (r *CityRepository) IsLaunchRegionActive(ctx context.Context, countryCode, provinceCode string) (bool, bool, error) {
	params := url.Values{}
	params.Set("select", "is_active")
	params.Set("country_code", "eq."+countryCode)
	params.Set("province_code", "eq."+provinceCode)
	params.Set("limit", "1")

	var rows []struct {
		IsActive bool `json:"is_active"`
	}
	if err := r.client.get(ctx, "/rest/v1/launch_regions", params, &rows); err != nil {
		return false, false, fmt.Errorf("IsLaunchRegionActive: %w", err)
	}
	if len(rows) == 0 {
		return false, false, nil
	}
	return rows[0].IsActive, true, nil
}
