# HeyCaby Scale Load Test Runbook

This runbook moves scale readiness from review confidence to measured evidence.
Run it before any App Store / physical-device certification pass that depends on
the current backend shape.

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

The harness writes:

- `build/load/interval_3s_samples.jsonl`
- `build/load/interval_5s_samples.jsonl`
- `build/load/interval_10s_samples.jsonl`
- `build/load/scale_summary.json`
- `build/load/scale_drivers.jsonl`

Do not commit generated `build/load/*` output.

## Staging Driver Pool

Prefer a staging project seeded with synthetic drivers:

```bash
python3 scripts/supabase_scale_swarm.py \
  --driver-source seed \
  --drivers 5000 \
  --intervals 3,5,10 \
  --duration-sec 300 \
  --rider-nearby-rps 25 \
  --rider-booking-rps 1 \
  --output-dir build/load
```

After the first seed, reuse the generated manifest to avoid recreating 5,000
Auth users every run:

```bash
python3 scripts/supabase_scale_swarm.py \
  --driver-source manifest \
  --manifest build/load/scale_drivers.jsonl \
  --drivers 5000 \
  --intervals 3,5,10 \
  --duration-sec 300 \
  --rider-nearby-rps 25 \
  --rider-booking-rps 1 \
  --output-dir build/load
```

## Required Runs

Run each interval separately and keep rider activity enabled:

```bash
python3 scripts/supabase_scale_swarm.py --driver-source manifest --intervals 3  --duration-sec 300
python3 scripts/supabase_scale_swarm.py --driver-source manifest --intervals 5  --duration-sec 300
python3 scripts/supabase_scale_swarm.py --driver-source manifest --intervals 10 --duration-sec 300
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

1. Run the 5k driver harness at 3s, 5s, and 10s.
2. Layer rider nearby/search and booking/dispatch in the same runs.
3. Capture database, WAL, slow query, CPU, and Realtime metrics.
4. Add indexes or rewrite hot paths based on observed slow queries.
5. Add server-side throttling/rate limiting for driver location updates.
6. Decide and implement current-location vs location-history separation.
7. Re-run the full load suite.
8. Only then continue physical-device and App Store certification.

