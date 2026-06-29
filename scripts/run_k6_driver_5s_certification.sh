#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${ENV_FILE:-.env.scale.staging}"
RUN_LABEL="${RUN_LABEL:-k6_5s_driver_only_$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="${RUN_DIR:-build/load/$RUN_LABEL}"
DRIVER_MANIFEST="${DRIVER_MANIFEST:-$ROOT_DIR/build/load/k6_scale_drivers.json}"
DRIVERS="${DRIVERS:-5000}"
UPDATE_INTERVAL_SEC="${UPDATE_INTERVAL_SEC:-5}"
DURATION="${DURATION:-5m}"
RAMP_UP="${RAMP_UP:-30s}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" || -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_DB_URL are required" >&2
  exit 1
fi

if [[ ! -f "$DRIVER_MANIFEST" ]]; then
  echo "Missing k6 driver manifest: $DRIVER_MANIFEST" >&2
  echo "Generate it with scripts/export_k6_driver_manifest.py before running." >&2
  exit 1
fi

mkdir -p "$RUN_DIR"

capture_pg_stats() {
  local output="$1"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -X -At -o "$output" -f - <<'SQL'
select jsonb_pretty(jsonb_build_object(
  'captured_at', now(),
  'database', current_database(),
  'activity', (
    select jsonb_build_object(
      'connections_total', count(*),
      'connections_active', count(*) filter (where state='active'),
      'waiting', count(*) filter (where wait_event is not null)
    )
    from pg_stat_activity
    where datname = current_database()
  ),
  'db_stats', (
    select to_jsonb(s)
    from (
      select xact_commit, xact_rollback, blks_read, blks_hit, tup_inserted,
             tup_updated, tup_deleted, deadlocks, temp_bytes
      from pg_stat_database
      where datname = current_database()
    ) s
  ),
  'location_statements', (
    select coalesce(jsonb_agg(to_jsonb(s) order by s.total_exec_time_ms desc), '[]'::jsonb)
    from (
      select queryid, calls, round(total_exec_time::numeric,2) as total_exec_time_ms,
             round(mean_exec_time::numeric,4) as mean_exec_time_ms,
             round(max_exec_time::numeric,2) as max_exec_time_ms, rows,
             shared_blks_hit, shared_blks_read, shared_blks_dirtied,
             shared_blks_written, wal_records, wal_bytes, left(query, 700) as query
      from extensions.pg_stat_statements
      where query ilike '%driver_locations%'
      order by total_exec_time desc
      limit 10
    ) s
  )
));
SQL
}

echo "Run label: $RUN_LABEL"
echo "Run dir: $RUN_DIR"
echo "Drivers: $DRIVERS"
echo "Interval: ${UPDATE_INTERVAL_SEC}s"
echo "Duration: $DURATION"
echo "Open Supabase dashboard metrics before continuing: CPU, API, DB connections, WAL, slow queries, Realtime."

capture_pg_stats "$RUN_DIR/pre_location_pg_stat.json"

K6_SUMMARY="$ROOT_DIR/$RUN_DIR/k6_summary.json" \
DRIVER_MANIFEST="$DRIVER_MANIFEST" \
DRIVERS="$DRIVERS" \
UPDATE_INTERVAL_SEC="$UPDATE_INTERVAL_SEC" \
DURATION="$DURATION" \
RAMP_UP="$RAMP_UP" \
k6 run scripts/k6_driver_location.js

capture_pg_stats "$RUN_DIR/post_location_pg_stat.json"

echo "Wrote:"
echo "  $RUN_DIR/k6_summary.json"
echo "  $RUN_DIR/pre_location_pg_stat.json"
echo "  $RUN_DIR/post_location_pg_stat.json"
