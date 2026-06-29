# HeyCaby Scale Load Test Runbook

This runbook moves scale readiness from review confidence to measured evidence.
Run it before any App Store / physical-device certification pass that depends on
the current backend shape.

## Current Certification Status

- 10-second driver location updates with 5,000 drivers: **CERTIFIED**
- 5-second driver location updates with 5,000 drivers: **NOT CERTIFIED**
- 3-second driver density: **BLOCKED**
- rider worst-case / combined driver+rider load: **BLOCKED**

Certified launch baseline:

```text
Idle online drivers: 10s updates
5,000 drivers
~500 writes/sec
0 errors
```

Do not run every idle driver at 5s or 3s. Do not rerun 5s unchanged. The next
workstream is Supabase API/request-path capacity and staging plan/tier
investigation.

## Goal

Prove or disprove that the platform can sustain:

- 5,000 concurrently active drivers
- driver location updates at 3s, 5s, and 10s intervals, run separately
- rider nearby search and booking/dispatch load layered on top of driver load

The app is not scale-ready until these runs produce acceptable latency,
error-rate, database, WAL, connection, and Realtime numbers.

## Harness

Use:

```bash
python3 scripts/supabase_scale_swarm.py
```

Required environment:

```bash
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_ANON_KEY="<anon key>"
export SUPABASE_SERVICE_KEY="<service role key>"
export SUPABASE_JWT_SECRET="<jwt secret>"
```

Optional but strongly recommended for DB metric snapshots:

```bash
export SUPABASE_DB_URL="postgresql://postgres:<password>@<host>:5432/postgres"
```

For measured runs, `SUPABASE_DB_URL` is required. The harness only allows
missing DB access when `--allow-missing-db-url` is passed for local smoke checks.

## Access Gate

Do not run load against production. Before any measured run, unblock staging:

- staging `SUPABASE_URL`
- staging `SUPABASE_ANON_KEY`
- staging `SUPABASE_SERVICE_KEY`
- staging `SUPABASE_JWT_SECRET`
- staging `SUPABASE_DB_URL`
- Supabase dashboard access for CPU, WAL/write volume, slow query log, DB
  connections, and Realtime fanout/connection metrics

Current local status must be checked before the run:

```bash
python3 - <<'PY'
import os
for key in [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_KEY',
    'SUPABASE_JWT_SECRET',
    'SUPABASE_DB_URL',
]:
    print(f'{key}={"present" if os.getenv(key) else "missing"}')
PY
```

If dashboard access or the staging plan tier does not expose these metrics, stop
and have Qb grant access or upgrade staging before test day. Missing observability
turns the load run into noise.

The harness writes:

- `build/load/<run-label>/interval_3s_samples.jsonl`
- `build/load/<run-label>/interval_3s_summary.json`
- `build/load/<run-label>/interval_5s_samples.jsonl`
- `build/load/<run-label>/interval_5s_summary.json`
- `build/load/<run-label>/interval_10s_samples.jsonl`
- `build/load/<run-label>/interval_10s_summary.json`
- `build/load/<run-label>/scale_summary.json`
- `build/load/scale_drivers.jsonl`

Do not commit generated `build/load/*` output.

Driver write samples include split latency metrics:

- `driver_location`: total observed latency from scheduling to completion
- `driver_location_http`: HTTP request latency inside the worker
- `driver_location_queue`: local load-generator backlog / scheduling latency
- `driver_futures_inflight`: in-flight driver write futures at sample time
- `driver_due_ready`: driver writes ready to be submitted at sample time
- `driver_due_submitted`: driver writes submitted at sample time
- `driver_backpressure_limited`: whether the harness intentionally held back
  submissions to avoid unbounded local queueing
- `max_driver_futures`: the in-flight cap for submitted driver writes
- `generator`: local process telemetry including CPU time, estimated CPU percent
  between samples, max RSS, active Python thread count, and a marker that
  per-process network bytes are not captured by the stdlib harness

Use these fields before blaming the database or Supabase API layer. A 5s run
with high total latency but low HTTP latency is a load-generator bottleneck, not
a backend certification failure.

For certification runs, keep `driver_location_queue` bounded. If
`driver_backpressure_limited` is true for most samples, the run measured the
generator/request-path throughput ceiling, not a clean backend pass.

## Staging Representativeness Gate

Document staging vs production before the first run:

| Item | Staging | Production target | Match? | Notes |
|---|---:|---:|---|---|
| Supabase plan/tier | TBD | TBD | TBD | Required before run |
| Postgres compute size | TBD | TBD | TBD | Required before run |
| Postgres version | TBD | TBD | TBD | Required before run |
| Direct DB max connections | TBD | TBD | TBD | Required before run |
| Pooler mode/limits | TBD | TBD | TBD | Required before run |
| Realtime limits | TBD | TBD | TBD | Required before run |
| Existing indexes on hot paths | TBD | TBD | TBD | Required before run |

A smaller staging instance can produce a false failure. A larger staging instance
can produce a false pass. Differences are acceptable only when they are explicit
and included in the CTO scale review.

## Staging Driver Pool

Prefer a staging project seeded with synthetic drivers. For the first large
staging seed, use the Postgres-backed seed path so Auth Admin provisioning does
not dominate the load-test setup time:

```bash
python3 scripts/supabase_scale_swarm.py \
  --driver-source db-seed \
  --drivers 5000 \
  --intervals 10 \
  --duration-sec 300 \
  --rider-nearby-rps 0 \
  --rider-booking-rps 0 \
  --run-label 10s_infra_validation \
  --output-dir build/load
```

After the first seed, reuse the generated manifest to avoid recreating 5,000
Auth users every run:

```bash
python3 scripts/supabase_scale_swarm.py \
  --driver-source manifest \
  --manifest build/load/scale_drivers.jsonl \
  --drivers 5000 \
  --intervals 10 \
  --duration-sec 300 \
  --rider-nearby-rps 0 \
  --rider-booking-rps 0 \
  --run-label 10s_infra_validation \
  --output-dir build/load
```

## Required Runs

## k6 Certification Harness

The Python harness is a discovery tool. It certified the 10-second baseline, but
it plateaued around 500 writes/sec on a single machine and must not be used as
the final certification tool for 5-second, 3-second, or rider worst-case scale.

Use k6 for the next 5-second certification attempt.

Install k6:

```bash
brew install k6
```

Export a k6 driver manifest from staging:

```bash
set -a
source .env.scale.staging
set +a
python3 scripts/export_k6_driver_manifest.py \
  --drivers 5000 \
  --output build/load/k6_scale_drivers.json
```

The manifest contains signed synthetic driver tokens. Keep it under
`build/load/` and do not commit it.

Run the 5-second driver-only k6 test:

```bash
./scripts/run_k6_driver_5s_certification.sh
```

The wrapper captures pre/post `pg_stat_statements` snapshots and writes a k6
summary under `build/load/<run-label>/`. It still requires the Supabase dashboard
to be open for CPU, API, WAL, slow-query, and Realtime metrics.

Required interpretation:

- If k6 sustains ~1,000 writes/sec with acceptable HTTP p95/p99 and error rate,
  the 5-second driver-only path can move toward certification.
- If k6 also plateaus around ~500 writes/sec while the generator machine is not
  CPU/network bound, investigate Supabase/API request path limits.
- If k6 itself becomes CPU/network bound, move to distributed generators before
  making backend claims.

Capture alongside the k6 JSON summary:

- Supabase dashboard CPU
- Supabase API metrics
- DB connections
- `pg_stat_statements` deltas
- WAL delta
- generator CPU/memory/network

Do not run 3-second or rider worst-case tests until the k6 5-second driver-only
test is clean.

## Python Discovery Runs

Run each interval separately. Start with 10s to validate the harness and metrics
capture, then step up only after the previous run produced a clean summary and DB
stats.

```bash
python3 scripts/supabase_scale_swarm.py \
  --driver-source manifest \
  --manifest build/load/scale_drivers.jsonl \
  --intervals 10 \
  --duration-sec 300 \
  --rider-nearby-rps 0 \
  --rider-booking-rps 0 \
  --run-label 10s_driver_only

python3 scripts/supabase_scale_swarm.py \
  --driver-source manifest \
  --manifest build/load/scale_drivers.jsonl \
  --intervals 5 \
  --duration-sec 300 \
  --max-driver-futures 1000 \
  --rider-nearby-rps 0 \
  --rider-booking-rps 0 \
  --run-label 5s_driver_only

python3 scripts/supabase_scale_swarm.py \
  --driver-source manifest \
  --manifest build/load/scale_drivers.jsonl \
  --intervals 3 \
  --duration-sec 300 \
  --rider-nearby-rps 25 \
  --rider-booking-rps 1 \
  --run-label 3s_driver_plus_rider_dispatch
```

Expected driver write pressure:

| Interval | Target location writes/sec |
|---|---:|
| 3s | ~1,667/sec |
| 5s | ~1,000/sec |
| 10s | ~500/sec |

## Required Measurements

The harness captures client latency/error metrics and optional Postgres snapshots.
During every run, also record from Supabase dashboard/logging:

- CPU at peak
- active DB connections
- WAL/write volume
- slow query log
- Realtime connected clients
- Realtime fanout/throughput
- API error rate and status-code split

If these cannot be captured, stop. A load test without observability is not
evidence.

Attach one row per run:

| Run label | Driver interval | Rider nearby RPS | Booking RPS | CPU peak | Active DB conns peak | WAL volume | Slow queries | Realtime conns/fanout | Driver write p95 | Nearby p95 | Booking+matching p95 | Error rate | Pass/fail |
|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---|
| `10s_driver_only` | 10s | 0 | 0 | TBD | TBD | TBD | TBD | TBD | TBD | n/a | n/a | TBD | TBD |
| `5s_driver_only` | 5s | 0 | 0 | TBD | TBD | TBD | TBD | TBD | TBD | n/a | n/a | TBD | TBD |
| `3s_driver_plus_rider_dispatch` | 3s | 25 | 1 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Hot Path Audit Before Re-Test

After the first run, inspect the slowest queries and run `EXPLAIN ANALYZE` for
the actual hot paths:

- `driver_locations` upsert by `user_id`
- `fn_rider_nearby_supply`
- `fn_seed_ride_matching_batch`
- ride lifecycle transitions on `ride_requests`
- active ride / driver restore queries
- chat and notification fanout queries, if active during the run

Any slow path needs an index or query rewrite before the second run.

## Pass Criteria

Set final thresholds with the CTO before signing off. Initial suggested gates:

- driver location write error rate below 0.5%
- rider nearby-supply p95 below 500 ms and p99 below 1,000 ms
- booking + matching p95 below 1,500 ms and p99 below 3,000 ms
- no sustained DB connection exhaustion
- no WAL/checkpoint backlog that continues after the run
- no Realtime fanout degradation for active ride listeners
- no duplicate assignment or invite corruption

If any 3s, 5s, or 10s run fails, the platform is not proven scale-ready at that
cadence.

## Ordering

1. Unblock staging credentials and dashboard access.
2. Confirm staging is representative or document every difference.
3. Run the 5k driver harness at 10s first.
4. Step up to 5s only after the 10s artifact is clean.
5. Step up to 3s only after the 5s artifact is clean.
6. Layer rider nearby/search and booking/dispatch onto the 3s run.
7. Capture database, WAL, slow query, CPU, and Realtime metrics.
8. Add indexes or rewrite hot paths based on observed slow queries.
9. Add server-side throttling/rate limiting for driver location updates.
10. Decide and implement current-location vs location-history separation.
11. Re-run the full load suite.
12. Only then continue physical-device and App Store certification.
