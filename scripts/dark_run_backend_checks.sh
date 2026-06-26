#!/usr/bin/env bash
set -euo pipefail

# Dark-run backend verification checks.
# Usage:
#   API_BASE_URL="https://api.heycaby.nl" ./scripts/dark_run_backend_checks.sh
# Optional auth checks:
#   DRIVER_TOKEN="..." RIDER_TOKEN="..." API_BASE_URL="https://api.heycaby.nl" ./scripts/dark_run_backend_checks.sh

API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
DRIVER_TOKEN="${DRIVER_TOKEN:-}"
RIDER_TOKEN="${RIDER_TOKEN:-}"
CITY_ID="${CITY_ID:-}"
LAT="${LAT:-52.0907}"
LNG="${LNG:-4.3000}"
RIDE_ID="${RIDE_ID:-00000000-0000-0000-0000-000000000000}"

pass() { printf "PASS  %s\n" "$1"; }
fail() { printf "FAIL  %s\n" "$1"; exit 1; }
warn() { printf "WARN  %s\n" "$1"; }

http_code() {
  local method="$1"
  local url="$2"
  local auth="${3:-}"
  local body="${4:-}"
  local extra_header="${5:-}"
  if [[ -n "$body" ]]; then
    curl -sS -o /tmp/heycaby_dark_run_response.json -w "%{http_code}" \
      -X "$method" "$url" \
      -H "Content-Type: application/json" \
      ${auth:+-H "Authorization: Bearer $auth"} \
      ${extra_header:+-H "$extra_header"} \
      --data "$body"
  else
    curl -sS -o /tmp/heycaby_dark_run_response.json -w "%{http_code}" \
      -X "$method" "$url" \
      ${auth:+-H "Authorization: Bearer $auth"} \
      ${extra_header:+-H "$extra_header"}
  fi
}

echo "Running dark-run checks against: $API_BASE_URL"

# Public health checks
code="$(http_code GET "$API_BASE_URL/health")"
[[ "$code" == "200" ]] && pass "GET /health -> 200" || fail "GET /health -> $code"

code="$(http_code GET "$API_BASE_URL/health/ready")"
if [[ "$code" == "200" || "$code" == "503" ]]; then
  pass "GET /health/ready -> $code (expected 200 or 503)"
else
  fail "GET /health/ready -> $code (expected 200 or 503)"
fi

if [[ -z "$DRIVER_TOKEN" ]]; then
  warn "DRIVER_TOKEN not set: skipping authenticated driver checks"
else
  # Boot config (driver auth)
  code="$(http_code GET "$API_BASE_URL/api/v1/config" "$DRIVER_TOKEN")"
  [[ "$code" == "200" ]] && pass "GET /api/v1/config (driver) -> 200" || fail "GET /api/v1/config (driver) -> $code"

  # Driver endpoints
  code="$(http_code GET "$API_BASE_URL/api/v1/driver/readiness" "$DRIVER_TOKEN")"
  [[ "$code" == "200" ]] && pass "GET /api/v1/driver/readiness -> 200" || fail "GET /api/v1/driver/readiness -> $code"

  code="$(http_code POST "$API_BASE_URL/api/v1/driver/heartbeat" "$DRIVER_TOKEN" "{\"lat\":$LAT,\"lng\":$LNG}")"
  [[ "$code" == "200" ]] && pass "POST /api/v1/driver/heartbeat -> 200" || fail "POST /api/v1/driver/heartbeat -> $code"

  code="$(http_code POST "$API_BASE_URL/api/v1/driver/status" "$DRIVER_TOKEN" '{"status":"available"}')"
  [[ "$code" == "200" ]] && pass "POST /api/v1/driver/status -> 200" || fail "POST /api/v1/driver/status -> $code"

  code="$(http_code POST "$API_BASE_URL/api/v1/driver/ride/$RIDE_ID/accept" "$DRIVER_TOKEN")"
  if [[ "$code" == "200" || "$code" == "400" || "$code" == "404" ]]; then
    pass "POST /api/v1/driver/ride/:id/accept -> $code (reachable)"
  else
    fail "POST /api/v1/driver/ride/:id/accept -> $code"
  fi
fi

if [[ -z "$RIDER_TOKEN" ]]; then
  warn "RIDER_TOKEN not set: skipping rider-role and nearby-supply checks"
else
  # Rider role should be forbidden on driver lifecycle route
  code="$(http_code POST "$API_BASE_URL/api/v1/driver/ride/$RIDE_ID/accept" "$RIDER_TOKEN")"
  [[ "$code" == "403" ]] && pass "Rider blocked on driver ride accept -> 403" || fail "Rider blocked on driver ride accept -> $code"

  # Nearby supply check (city header optional)
  if [[ -n "$CITY_ID" ]]; then
    code="$(http_code GET "$API_BASE_URL/api/v1/rider/nearby-supply?lat=$LAT&lng=$LNG" "$RIDER_TOKEN" "" "X-City-Id: $CITY_ID")"
  else
    code="$(http_code GET "$API_BASE_URL/api/v1/rider/nearby-supply?lat=$LAT&lng=$LNG" "$RIDER_TOKEN")"
  fi
  [[ "$code" == "200" ]] && pass "GET /api/v1/rider/nearby-supply -> 200" || fail "GET /api/v1/rider/nearby-supply -> $code"
fi

echo "Dark-run checks completed."
