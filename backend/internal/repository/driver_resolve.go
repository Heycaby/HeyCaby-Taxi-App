package repository

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
)

// ErrDriverNotFound is returned when no drivers row matches the auth user or legacy id.
var ErrDriverNotFound = errors.New("driver not found")

// ResolveDriverID maps JWT auth.users.id (drivers.user_id) to public.drivers.id.
// Also accepts drivers.id directly for legacy callers.
func (r *DriverRepository) ResolveDriverID(ctx context.Context, authUserOrDriverID string) (string, error) {
	id := strings.TrimSpace(authUserOrDriverID)
	if id == "" {
		return "", fmt.Errorf("%w: empty id", ErrDriverNotFound)
	}

	params := url.Values{}
	params.Set("select", "id")
	params.Set("id", "eq."+id)
	params.Set("limit", "1")

	var byID []struct {
		ID string `json:"id"`
	}
	if err := r.client.get(ctx, "/rest/v1/drivers", params, &byID); err != nil {
		return "", fmt.Errorf("ResolveDriverID: %w", err)
	}
	if len(byID) > 0 && byID[0].ID != "" {
		return byID[0].ID, nil
	}

	params = url.Values{}
	params.Set("select", "id")
	params.Set("user_id", "eq."+id)
	params.Set("limit", "1")

	var byUser []struct {
		ID string `json:"id"`
	}
	if err := r.client.get(ctx, "/rest/v1/drivers", params, &byUser); err != nil {
		return "", fmt.Errorf("ResolveDriverID: %w", err)
	}
	if len(byUser) == 0 || byUser[0].ID == "" {
		return "", fmt.Errorf("%w: user %s", ErrDriverNotFound, id)
	}
	return byUser[0].ID, nil
}
