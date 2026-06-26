#!/usr/bin/env bash
set -euo pipefail

# Runs the NL rollout health SQL report against a Postgres connection.
# Usage:
#   SUPABASE_DB_URL="postgresql://..." ./scripts/run_nl_rollout_health_report.sh
#
# Optional:
#   SQL_FILE="scripts/sql/nl_rollout_health_report.sql" SUPABASE_DB_URL="..." ./scripts/run_nl_rollout_health_report.sh

SQL_FILE="${SQL_FILE:-scripts/sql/nl_rollout_health_report.sql}"
DB_URL="${SUPABASE_DB_URL:-}"

if [[ -z "${DB_URL}" ]]; then
  echo "ERROR: SUPABASE_DB_URL is required." >&2
  echo "Example:" >&2
  echo "  SUPABASE_DB_URL=\"postgresql://...\" ./scripts/run_nl_rollout_health_report.sh" >&2
  exit 1
fi

if [[ ! -f "${SQL_FILE}" ]]; then
  echo "ERROR: SQL file not found: ${SQL_FILE}" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql is required but not found in PATH." >&2
  exit 1
fi

echo "Running NL rollout health report..."
RAW_JSON="$(
  psql "${DB_URL}" \
    --no-psqlrc \
    --tuples-only \
    --no-align \
    --quiet \
    --file "${SQL_FILE}" \
    | tr -d '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
)"

if [[ -z "${RAW_JSON}" ]]; then
  echo "ERROR: Report query returned empty output." >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  echo "${RAW_JSON}" | jq .
else
  echo "${RAW_JSON}"
fi

