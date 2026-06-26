#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

check_no_matches() {
  local description="$1"
  local pattern="$2"
  local path="$3"

  if rg --pcre2 -n "$pattern" "$path" >/tmp/heycaby_boundary_check.txt 2>/dev/null; then
    echo "FAIL: $description"
    cat /tmp/heycaby_boundary_check.txt
    echo
    failures=$((failures + 1))
  else
    echo "PASS: $description"
  fi
}

echo "Running monorepo boundary checks..."
echo

check_no_matches \
  "No legacy PATCH /api/driver/status in Dart app code" \
  "patch\((\"|')/api/driver/status(\"|')" \
  "apps packages"

check_no_matches \
  "No direct rider queries to driver_locations table" \
  "from\((\"|')driver_locations(\"|')\)" \
  "apps/rider/lib"

check_no_matches \
  "No direct rider matching reads from drivers table" \
  "from\((\"|')drivers(\"|')\).*select\(" \
  "apps/rider/lib"

check_no_matches \
  "No direct driver Edge Function verify-chauffeurspas calls" \
  "functions\.invoke\((\"|')verify-chauffeurspas(\"|')" \
  "apps/driver/lib"

check_no_matches \
  "No direct rider ride_requests business-logic reads (must go via backend for policy decisions)" \
  "from\((\"|')ride_requests(\"|')\)" \
  "apps/rider/lib/screens apps/rider/lib/widgets apps/rider/lib/services"

check_no_matches \
  "No direct driver readiness/compliance policy reads from drivers table in UI/services" \
  "from\((\"|')drivers(\"|')\).*select\((\"|').*(kvk|chauffeurspas|insurance|rijbewijs|compliance_status)" \
  "apps/driver/lib"

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "Boundary checks failed: $failures violation(s)."
  exit 1
fi

echo
echo "Boundary checks passed."
