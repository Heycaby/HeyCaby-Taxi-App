# Monorepo Boundaries

This repo stays a single monorepo, but with strict separation of concerns.

## Ownership

- `apps/rider/` and `apps/driver/`: UI rendering + device capabilities only.
- `backend/`: business rules, validations, eligibility, pricing, matching decisions.
- `packages/heycaby_api/`: typed API clients and transport.
- `packages/heycaby_models/`: shared response/request models only.

## Boundary Rules

1. Flutter apps do not decide policy (`can_go_online`, compliance, fare rules).
2. Rider app must not query `driver_locations` directly.
3. Driver app must not call legacy `PATCH /api/driver/status`.
4. Driver app must not call `verify-chauffeurspas` Edge Function directly.
5. Server-driven endpoints are authoritative:
   - `GET /api/v1/config`
   - `GET /api/v1/driver/readiness`
   - `POST /api/v1/driver/document/validate`
   - `GET /api/v1/rider/nearby-supply`
   - `POST /api/v1/driver/status`

## Enforcement

Boundary checks run with:

- `./scripts/enforce_monorepo_boundaries.sh`
- `melos run guard:boundaries`
- GitLab CI job: `boundaries_check`

If these checks fail, treat it as an architecture regression.

## Guarded Patterns

Current automated checks fail the build when they detect:

- legacy `PATCH /api/driver/status` calls
- Rider direct `driver_locations` reads
- Rider direct `drivers` matching reads
- Rider direct `ride_requests` business-logic reads in app layers
- Driver direct `verify-chauffeurspas` Edge Function calls
- Driver direct `drivers` compliance/readiness field reads in app layers
