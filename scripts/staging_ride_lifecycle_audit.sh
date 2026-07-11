#!/usr/bin/env bash
# Phase 2A: Audit ride lifecycle matrix on HeyCaby Staging.
#
# Usage:
#   ./scripts/staging_ride_lifecycle_audit.sh <ride_request_id>
#   ./scripts/staging_ride_lifecycle_audit.sh --latest-completed
#
# Requires: supabase CLI linked to staging, or set SUPABASE_DB_URL.

set -euo pipefail

STAGING_REF="fdavszxncggswuiwggcp"
RIDE_ID="${1:-}"

if [[ "${1:-}" == "--latest-completed" ]]; then
  echo "Fetching latest completed ride on staging..."
  RIDE_ID=$(supabase db execute --project-ref "$STAGING_REF" --sql \
    "SELECT id::text FROM ride_requests WHERE status = 'completed' ORDER BY completed_at DESC NULLS LAST LIMIT 1;" \
    2>/dev/null | tail -1 | tr -d '[:space:]')
  if [[ -z "$RIDE_ID" ]]; then
    echo "No completed ride found."
    exit 1
  fi
  echo "Using ride_id=$RIDE_ID"
fi

if [[ -z "$RIDE_ID" ]]; then
  echo "Usage: $0 <ride_request_id>"
  echo "       $0 --latest-completed"
  exit 1
fi

echo "=== Ride Lifecycle Matrix Audit (staging) ==="
echo "ride_id=$RIDE_ID"
echo ""

supabase db execute --project-ref "$STAGING_REF" --sql \
  "SELECT jsonb_pretty(public.fn_ride_lifecycle_matrix_audit('$RIDE_ID'::uuid));"

echo ""
echo "=== Canonical event stream ==="
supabase db execute --project-ref "$STAGING_REF" --sql \
  "SELECT event_type, occurred_at FROM public.ride_events WHERE ride_id = '$RIDE_ID'::uuid ORDER BY occurred_at;"
