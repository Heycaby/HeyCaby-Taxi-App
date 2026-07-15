#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

manifest="supabase/functions/manifest.json"
failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

pass() {
  echo "PASS: $1"
}

if ! jq -e '.project_id and (.functions | length > 0)' "$manifest" >/dev/null; then
  fail "Edge Function manifest is valid"
else
  pass "Edge Function manifest is valid"
fi

while IFS= read -r function_name; do
  if [[ ! -f "supabase/functions/$function_name/index.ts" ]]; then
    fail "Function source exists: $function_name"
  fi
done < <(jq -r '.functions[].name' "$manifest")

while IFS= read -r function_dir; do
  function_name="$(basename "$function_dir")"
  if ! jq -e --arg name "$function_name" '.functions[] | select(.name == $name)' "$manifest" >/dev/null; then
    fail "Function is registered in manifest: $function_name"
  fi
done < <(find supabase/functions -mindepth 1 -maxdepth 1 -type d ! -name _shared | sort)

manifest_count="$(jq '.functions | length' "$manifest")"
source_count="$(find supabase/functions -mindepth 1 -maxdepth 1 -type d ! -name _shared | wc -l | tr -d ' ')"
if [[ "$manifest_count" != "$source_count" ]]; then
  fail "Manifest/source function counts match ($manifest_count != $source_count)"
else
  pass "All $source_count Edge Functions are registered and source-controlled"
fi

if rg -n "raw_user_meta_data.*role|role.*raw_user_meta_data" \
  supabase/functions supabase/migrations/20260713*_domain_authority*.sql >/tmp/heycaby_authority_findings.txt 2>/dev/null; then
  cat /tmp/heycaby_authority_findings.txt
  fail "Current privileged authorization never trusts raw_user_meta_data"
else
  pass "Current privileged authorization uses server-owned claims"
fi

if ! rg -q "authenticatedAdmin" supabase/functions/send-push/index.ts; then
  fail "Broadcast push has an explicit admin gate"
else
  pass "Broadcast push has an explicit admin gate"
fi

if ! rg -q "authenticatedAdmin" supabase/functions/send-driver-email/index.ts; then
  fail "Driver email has an explicit admin gate"
else
  pass "Driver email has an explicit admin gate"
fi

if ! rg -q 'fn_rider_agent_webhook_secret' \
  supabase/functions/rider-lifecycle-dispatch/index.ts \
  || ! rg -q 'dry_run' \
  supabase/functions/rider-lifecycle-dispatch/index.ts \
  || ! rg -q 'RIDER_AGENT_WEBHOOK_SECRET' \
  supabase/functions/rider-lifecycle-dispatch/auth.ts \
  || [[ ! -s supabase/functions/rider-lifecycle-dispatch/auth_test.ts ]]; then
  fail "Rider lifecycle cron and Edge Function share Vault-backed auth authority"
else
  pass "Rider lifecycle dispatch uses Vault-backed auth with a safe dry-run probe"
fi

if rg -n "skipping HMAC|SIM_MODE|simulation.*true" \
  supabase/functions/veriff-webhook \
  supabase/functions/create-driver-veriff-session \
  supabase/functions/verify-chauffeurspas >/tmp/heycaby_authority_findings.txt 2>/dev/null; then
  cat /tmp/heycaby_authority_findings.txt
  fail "Verification providers fail closed"
else
  pass "Verification providers fail closed"
fi

for test_file in \
  supabase/tests/domain_authority_phase0_test.sql \
  supabase/tests/receipt_single_authority_test.sql \
  supabase/tests/rider_create_ride_command_authority_harness.sql \
  supabase/tests/driver_accept_runtime_eligibility_harness.sql \
  supabase/tests/driver_accept_runtime_recheck_compile.sql \
  supabase/tests/scheduled_accept_authority_compile.sql; do
  if [[ ! -s "$test_file" ]]; then
    fail "Database authority test exists: $test_file"
  fi
done

accept_migration="supabase/migrations/20260714084941_driver_accept_runtime_recheck.sql"
accept_eligibility_migration="supabase/migrations/20260714084930_driver_accept_runtime_eligibility.sql"
accept_fit_migration="supabase/migrations/20260714090052_driver_accept_ride_fit_eligibility.sql"
scheduled_accept_migration="supabase/migrations/20260714090109_scheduled_accept_authority.sql"
if ! rg -q "FOR UPDATE" "$accept_migration" \
  || ! rg -q "ride_expired" "$accept_migration" \
  || ! rg -q "fn_driver_accept_runtime_eligibility" "$accept_migration" \
  || ! rg -q "expires_at > now\(\)" "$accept_migration" \
  || ! rg -q "fn_driver_readiness_eval" "$accept_eligibility_migration" \
  || ! rg -q "filter_electric" "$accept_fit_migration" \
  || ! rg -q "filter_wheelchair" "$accept_fit_migration" \
  || ! rg -q "FOR UPDATE" "$scheduled_accept_migration" \
  || ! rg -q "scheduled_departed" "$scheduled_accept_migration" \
  || ! rg -q "dispatch.scheduled_accept_rejected" "$scheduled_accept_migration"; then
  fail "Atomic accept rechecks live invite, ride expiry, and Driver eligibility"
else
  pass "Live and scheduled acceptance recheck expiry and Driver eligibility"
fi

rider_booking_source="apps/rider/lib/providers/ride_request_provider.dart"
if ! rg -q "fn_rider_create_ride" "$rider_booking_source"; then
  fail "Rider booking uses the canonical create command"
elif rg -U -q "from\\(['\"]ride_requests['\"]\\)[[:space:]]*\\.insert\\(" \
  "$rider_booking_source"; then
  fail "Rider booking has no direct ride_requests insert"
else
  pass "Rider booking uses one backend command authority"
fi

if [[ ! -s docs/domains/registry.yaml ]]; then
  fail "Domain ownership registry exists"
else
  pass "Domain ownership registry exists"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Domain authority checks failed: $failures"
  exit 1
fi

echo "Domain authority checks passed."
