package driverservice

import (
	"context"
	"errors"

	"github.com/heycaby/backend/internal/repository"
)

func (s *DriverService) resolveDriverID(ctx context.Context, authUserOrDriverID string) (string, error) {
	return s.drivers.ResolveDriverID(ctx, authUserOrDriverID)
}

func isDriverNotFound(err error) bool {
	return errors.Is(err, repository.ErrDriverNotFound)
}

// IsDriverNotFound reports missing driver rows for auth JWT sub → drivers.user_id lookup.
func IsDriverNotFound(err error) bool {
	return isDriverNotFound(err)
}
