# Scale Bottleneck Investigation - 2026-06-28

## Status

The 10-second driver-location load point is certified on staging:

- 5,000 drivers
- ~500 writes/sec
- 149,628 successful writes in 300 seconds
- 0 client errors
- p95 total driver write latency: 4,204 ms
- p99 total driver write latency: 4,616 ms

The 5-second load point is not certified:

- 5,000 drivers
- target ~1,000 writes/sec
- k6 actual throughput: 391.25 writes/sec
- k6 success rate: 38.98%
- k6 failure rate: 61.02%
- k6 HTTP p95: 10,000.48 ms
- DB mean execution for reached upserts: about 2 ms

Do not run another 5-second certification attempt unchanged. Do not run the
3-second driver test or rider worst-case test. The next workstream is Supabase
API/request-path capacity and staging plan/tier investigation, not backend
rewrite or blind database tuning.

## Key Findings

The database did not show collapse symptoms during the completed 10-second run:

- sampled DB connections peaked at 25 total / 8 active
- deadlocks stayed at 0
- rollback count stayed flat
- WAL delta from samples was about 201 MB

`pg_stat_statements` shows the PostgREST `driver_locations` upsert is the top
query by total database time, but its steady database execution time is low:

- calls: 211,793
- mean execution time: 1.63 ms
- max execution time: 401.74 ms
- WAL bytes: 245,363,108

That makes raw Postgres execution an unlikely explanation for 39-second client
p95 latency by itself.

## Location Write Path

`driver_locations` is not just one row and one index. The write path currently
does all of this:

- primary-key upsert on `user_id`
- RLS check: `auth.uid() = user_id`
- trigger: `trg_assign_driver_zone`
- trigger: `trigger_update_movement`
- maintenance for many secondary indexes, including latitude/longitude,
  `updated_at`, `driver_id`, country, zone, and city indexes

The table stats after load showed:

- `n_tup_upd`: 205,690
- `n_tup_hot_upd`: 0

So location updates are not HOT updates. Every heartbeat is doing index
maintenance. That is expected because indexed columns such as latitude,
longitude, `updated_at`, and possibly zone/city fields change.

## Trigger Findings

`trg_assign_driver_zone` calls:

```sql
public.fn_detect_zone(NEW.latitude, NEW.longitude)
```

That function performs a PostGIS `ST_Contains` lookup against
`bubble_zones.geom`.

Staging currently has no `bubble_zones` rows, so the trigger is not exercising
real production zone matching. A first rollback probe showed a cold-path outlier
around 223 ms in `trg_assign_driver_zone`; repeated warm probes were about
1-3 ms total. Do not treat the cold outlier as the sole root cause, but do treat
zone assignment as a known side effect that must be tested with representative
zone data before certification.

## Harness Finding

The original harness recorded driver write latency from task submission until
completion. Under high pressure, that can mix three different things:

- local executor queue/backlog time
- HTTP request time through Supabase REST/API gateway
- database execution time

The harness now records separate metrics:

- `driver_location`: total observed latency
- `driver_location_http`: actual HTTP request latency inside the worker
- `driver_location_queue`: local queue/backlog latency before/during worker
  scheduling
- `driver_futures_inflight`: active request backlog at each sample

A 100-driver smoke verified the new split metrics:

- total p95: 163.88 ms
- HTTP p95: 127.37 ms
- queue p95: 53.09 ms
- errors: 0

The next 5-second run must use this updated harness. If total latency rises but
HTTP latency stays low, the bottleneck is the local load generator. If HTTP
latency rises while Postgres execution stays low, the bottleneck is likely the
Supabase API/request path. If database execution rises, investigate SQL,
triggers, indexes, locks, and WAL.

## Phase 3 Split-Latency Retest

Run label:

```text
staging_5k_driver_5s_split_20260628
```

This run was intentionally aborted after the split metrics showed the sample was
no longer a valid backend certification run.

At about 80 seconds:

- completed writes/sec: ~474/sec against a 1,000/sec target
- successful writes: 38,063
- client errors: 0
- in-flight driver futures: 41,735
- total p95: 39,624 ms
- HTTP p95: 2,674 ms
- queue p95: 37,455 ms
- DB sampled peak connections: 25 total / 4 active
- deadlocks delta: 0
- `driver_locations` PostgREST statement delta: 46,043 calls
- `driver_locations` database execution mean stayed about 1.65 ms

Conclusion: this run primarily exposed local load-generator queueing. It should
not be used to certify or reject the backend at the 5-second interval.

The HTTP path still needs a cleaner measurement because HTTP p95 was materially
higher than the 100-driver smoke, but the dominant latency in this run was local
queue/backlog time.

Next harness requirement: add backpressure or constant-arrival-rate scheduling
so the generator does not enqueue tens of thousands of futures. A valid 5-second
certification run must keep generator queue latency bounded while measuring HTTP
and database latency separately.

Implemented follow-up: the harness now supports `--max-driver-futures` and
defaults it to `--driver-workers`. Samples now include:

- `driver_due_ready`
- `driver_due_submitted`
- `driver_backpressure_limited`
- `max_driver_futures`

This prevents unbounded local queueing. The next retest should be treated as a
request-path capacity test: if backpressure is active and throughput stays below
target while HTTP latency is high, the bottleneck is outside Postgres but still
in the request path. If backpressure is active while HTTP latency is low, the
load generator itself is too small and the test should move to k6/Artillery or a
distributed generator before making backend claims.

## Phase 3 Bounded Request-Path Test

Run label:

```text
staging_5k_driver_5s_backpressure_20260628
```

Configuration:

- 5,000 drivers
- 5-second interval target
- target throughput: 1,000 writes/sec
- `driver_workers`: 1,000
- `max_driver_futures`: 1,000
- rider load: disabled

Result:

- completed writes: 147,948
- actual throughput: 493.16 writes/sec
- errors: 0
- backpressure active: 29 / 31 samples
- max in-flight futures: 1,000
- max due-ready drivers observed: 2,793

Latency:

- total p95: 2,624.85 ms
- total p99: 3,291.94 ms
- HTTP p95: 2,541.75 ms
- HTTP p99: 3,235.06 ms
- queue p95: 186.8 ms
- queue p99: 517.58 ms

Database:

- sampled DB connection peak: 25 total / 8 active
- deadlocks delta: 0
- rollback delta: 0
- sampled WAL delta: ~190 MB
- `driver_locations` pg_stat delta: 147,948 calls
- approximate database mean execution from delta: 1.6857 ms

Conclusion: with local queueing bounded, the platform still did not reach the
5-second target throughput. Queue latency is no longer the dominant problem.
Postgres execution is still fast. The bottleneck is now narrowed to the
HTTP/Supabase request path and/or the single-machine generator's practical
concurrency ceiling. The next measurement should vary `max_driver_futures`
and/or use k6/Artillery/distributed generators to distinguish API path capacity
from Python thread/load-generator limits.

## Phase 3 Futures Sweep

Artifact:

```text
build/load/staging_5k_driver_5s_futures_sweep_20260628.json
```

Exploratory 90-second runs:

| max futures | actual writes/sec | errors | HTTP p95 | queue p95 | peak threads | result |
|---:|---:|---:|---:|---:|---:|---|
| 500 | 509.27 | 0 | 1,472.11 ms | 101.11 ms | 501 | completed |
| 1,000 | 508.52 | 0 | 2,744.61 ms | 89.25 ms | 1,001 | completed |
| 2,000 | 500.84 | 1,339 | 21,709.86 ms | 119.73 ms | 2,001 | aborted/partial |
| 5,000 | n/a | n/a | n/a | n/a | n/a | skipped |

The 5,000-futures point was intentionally skipped because 2,000 futures already
produced connection resets/timeouts, around 2,001 Python threads, and high local
memory pressure. Running 5,000 futures on the same Python generator would measure
local thread/generator collapse, not backend capacity.

Conclusion: increasing `max_driver_futures` from 500 to 1,000 did not increase
throughput; it only increased HTTP latency. Increasing to 2,000 still did not
increase throughput and introduced errors. On this single-machine Python
harness, the observed ceiling remains around 500 writes/sec.

This does not prove Supabase's platform ceiling. It proves that this Python
single-machine harness cannot certify 1,000 writes/sec. The next valid
experiment is a proper load tool or distributed generators.

## k6 Harness Setup

k6 was installed locally:

```text
k6 v2.0.0
```

Added:

- `scripts/export_k6_driver_manifest.py`
- `scripts/k6_driver_location.js`
- `scripts/run_k6_driver_5s_certification.sh`

Smoke run:

- drivers: 10
- interval: 2 seconds
- duration: 15 seconds
- writes: 70
- failures: 0
- HTTP p95: ~551 ms

The full staging k6 manifest was exported to:

```text
build/load/k6_scale_drivers.json
```

This file contains signed synthetic driver JWTs and must stay out of git.

The full 5,000-driver k6 certification run is prepared but should only start
with Supabase dashboard CPU/API/DB metrics open and `pg_stat_statements` pre/post
snapshots captured.

Preferred command once dashboard metrics are open:

```bash
./scripts/run_k6_driver_5s_certification.sh
```

## k6 5-Second Driver-Only Run

Run label:

```text
k6_5s_driver_only_20260628T222452Z
```

Result:

- VUs: 5,000
- duration: 5 minutes
- target: ~1,000 writes/sec
- actual writes: 134,085
- actual throughput: 391.25 writes/sec
- accepted writes: 52,272
- failed writes: 81,813
- success rate: 38.98%
- failure rate: 61.02%
- HTTP median: 4,220.27 ms
- HTTP p90: 10,000.30 ms
- HTTP p95: 10,000.48 ms
- HTTP max: 10,048.62 ms

Thresholds failed:

- `http_req_duration p95 < 3000`
- `http_req_duration p99 < 6000`
- `http_req_failed rate < 0.005`
- `driver_location_ok rate > 0.995`

Post-run database delta:

- `xact_commit`: +69,277
- `xact_rollback`: +0
- `tup_updated`: +69,018
- `deadlocks`: +0
- `driver_locations` pg_stat delta calls: 68,946
- approximate DB mean execution from delta: 2.0579 ms
- WAL bytes delta for the location statement: 81,236,938

Interpretation:

k6 produced the target-style 5,000-VU workload, and the 5-second test failed.
Postgres still did not collapse: DB execution remained around 2 ms per reached
location upsert, rollbacks and deadlocks stayed flat, and the failure mode was
HTTP timeout/error dominated. Supabase API logs visible through the connector
show successful `POST /rest/v1/driver_locations` samples, not SQL errors.

The 5-second path is therefore still **not certified**. The next decision is
whether to test the same k6 workload from distributed generators or investigate
staging/Supabase API request-path limits and plan/tier constraints with Supabase
dashboard evidence.

## Required Before Any Retest

Before another 5-second certification attempt:

- Investigate Supabase API/request-path limits and staging plan/tier constraints
  with dashboard evidence.
- Confirm whether the staging project tier is expected to sustain 5,000 VUs /
  ~1,000 REST writes/sec.
- Capture Supabase API metrics and status-code/error split for the failed k6 run
  if the dashboard retains them.
- Seed representative `bubble_zones` data in staging or explicitly document that
  staging zone detection is not representative.
- Capture Supabase dashboard CPU and API metrics during the run.
- Keep `pg_stat_statements` snapshots before and after the run.
- Use k6 or distributed generators, not the Python harness, for certification.
- Do not run the 3-second or rider worst-case test until the 5-second driver-only
  test passes cleanly.

## Launch Guardrail

Keep launch driver location interval at 10 seconds for idle online drivers.

Use faster intervals only for scoped ride states:

- idle online: 10s
- matched/en route: 5s
- active trip: 5s
- near pickup/dropoff: 3s
- background idle: 20-30s
