# HEYCABY Backend Simulation Smoke Test Master

Date: 2026-04-29  
Scope: Backend-only simulation and infrastructure validation (Go + Redis + Supabase + ECS/ALB).

## 1) Smoke Test Checklist

- [x] **Infra up**: ECS service healthy behind ALB.
- [x] **Secrets wiring**: `SUPABASE_SERVICE_KEY`, `SUPABASE_JWT_SECRET`, `REDIS_URL` loaded from Secrets Manager.
- [x] **Redis strict mode**: health reports `redis=ok` and `redis_required=true`.
- [x] **Atomic accept lock**: Redis `SET NX EX` lock on `ride:<ride_id>:accept_lock`.
- [x] **Single-winner DB update**: accept writes winner only through conditional status update.
- [x] **Go backend authority**: acceptance decided server-side (not client).
- [x] **Rider radius input**: `rider_radius_km` accepted and applied.
- [x] **Driver personal radius filter**: `pickup_distance_max_km` enforced in matching.
- [x] **Wave search order**: matching runs 5/10/25km progressive waves (capped by max radius).
- [x] **Scheduled lock flow parity**: simulated (`is_scheduled=true`) with 20 concurrent accepts; 1 winner, 19 conflicts.
- [x] **Marketplace lock flow parity**: simulated (`is_market=true`) with 20 concurrent accepts; 1 winner, 19 conflicts.
- [ ] **Cancellation billing assertions**: compensation and fee-side effects not yet validated end-to-end.
- [ ] **Load/perf simulation (1k rides / 10k drivers)**: full multi-ride + 10k-driver geo scenario not run yet.
- [x] **Bounded load proof (accept race)**: multi-round concurrent load executed with latency metrics.
- [x] **Chaos tests (Redis strict fail-closed)**: invalid Redis secret + forced restart produced expected `503 degraded` readiness and clean recovery after restore.
- [ ] **Chaos tests (Supabase timeout/failure)**: not run yet as formal suite.

## 2) Pass/Fail Matrix

| Layer | Result | Evidence | Notes |
|---|---|---|---|
| DB structure presence | **Partial Pass** | Supabase query shows only `cities`, `drivers`, `ride_requests`, `rides` from required list | Missing/renamed tables from requested canonical list (`scheduled_rides`, `marketplace_rides`, `driver_radius_settings`, etc.) |
| Redis locking correctness | **Pass (verified)** | Live simulation: 20 concurrent `/accept` calls -> 1x `200`, 19x `409`; DB winner is single driver | Concurrency proof executed on ride `966c085a-a37d-4c49-a3b7-55a82b1f0197` |
| Geo/radius matching | **Pass (logic)** | Wave search + rider cap + driver personal radius implemented | Needs scenario simulation assertions (Rotterdam examples) |
| Ride state transitions | **Partial Pass** | Conditional accept from `pending/searching`, lifecycle endpoints exist | Full state-machine guard matrix not fully enforced/tested |
| Cancellation flows | **Not Verified** | Endpoints exist | Billing/compensation policies not proven in simulation |
| Scheduled ride locking | **Pass (simulated)** | `is_scheduled=true` race run: 20 requests -> 1x200, 19x409, DB single winner | Uses shared accept endpoint; validate dedicated endpoint too if later added |
| Marketplace locking | **Pass (simulated)** | `is_market=true` race run: 20 requests -> 1x200, 19x409, DB single winner | Uses shared accept endpoint; validate dedicated endpoint too if later added |
| Payment/plan logic | **Not Verified** | Existing business logic in app/backend | Founding vs post-200 threshold simulation not executed |
| Country/city isolation | **Partial Pass** | Country/province context and launch gating exist | Cross-country leakage simulation not executed |
| Failure/chaos behavior | **Pass (Redis fail-closed verified)** | Injected invalid `REDIS_URL`, forced full ECS restart, `/health/ready` returned `503` with `redis_required=true`; restored secret and recovered to `200` | Supabase timeout injection still pending |
| Performance/scale | **Partial Pass** | `scripts/load_accept_race.py` now executed through 1,000 total accept attempts (10x100) with stable one-winner behavior and zero duplicate winners | This validates lock correctness at high contention for one ride; full 1k rides / 10k drivers geo-dispatch scenario still pending |

## 3) Bug Report (Current Known Gaps)

### High Priority

1. **Required table set mismatch vs target model**
   - Requested smoke list includes `scheduled_rides`, `marketplace_rides`, `driver_radius_settings`, etc.
   - Current DB check found only `cities`, `drivers`, `ride_requests`, `rides` in that exact set.
   - Action: map canonical product entities to actual schema or add missing tables/views.

2. **No executed concurrent proof yet for "20 accepts, 1 winner"**
   - Resolved in latest run:
     - `TOTAL 20`
     - `SUCCESS_200 1`
     - `CONFLICT_409 19`
   - DB after run shows single accepted assignment.

3. **Scheduled + marketplace lock parity unproven** (Resolved via simulation)
   - Scheduled simulation (`is_scheduled=true`) passed with one winner.
   - Marketplace simulation (`is_market=true`) passed with one winner.
   - Need explicit endpoint-level race simulations with same strict lock outcomes.

### Medium Priority

4. **Lifecycle strictness incomplete**
   - Need strict rejection tests for invalid jumps (`requested -> completed` etc.).

5. **Acceptance timestamp not written** (Resolved)
   - Fix deployed: conditional accept update now writes `accepted_at`.
   - Re-run result:
     - `TOTAL 20`
     - `SUCCESS_200 1`
     - `CONFLICT_409 19`
     - DB row confirms non-null `accepted_at` and winner driver.

5. **Cancellation economics unverified**
   - Need assertions for rider/driver cancel timing and compensation effects.

## 4) Scalability Report (Preliminary)

### Current posture

- **Good foundations**
  - Redis-backed lock and geo-enabled matching path.
  - Progressive radius waves reduce blast-notification behavior.
  - Driver/rider radius constraints are now server-enforced.

- **Risk before high volume**
  - No measured p95/p99 match and lock latency under load.
  - No evidence yet for contention behavior at high accept concurrency.
  - No formal chaos/failure budget test outputs.

### Required pre-launch simulation suite

- **Concurrency test**: 20/50/100 simultaneous accepts per same ride.
- **Load test**: 1k ride requests with 10k driver location set.
- **Failure test**: Redis timeout, Supabase write timeout, process restart.
- **Metrics capture**:
  - Match latency (p50/p95/p99)
  - Lock acquisition latency
  - Lock collision rate
  - Duplicate assignment count (must be zero)
  - Radius violation count (must be zero)

### Executed bounded load result

- Harness: `scripts/load_accept_race.py`
- Stage A config: `5 rounds x 20 concurrent` (`100` requests)
  - Outcomes: `200=5`, `409=95`, `other=0`, `one-winner rounds=5/5`
  - Latency: avg `123.08 ms`, p50 `110.52 ms`, p95 `154.93 ms`, p99 `208.45 ms`
- Stage B config: `3 rounds x 50 concurrent` (`150` requests)
  - Outcomes: `200=3`, `409=147`, `other=0`, `one-winner rounds=3/3`
  - Latency: avg `137.16 ms`, p50 `126.97 ms`, p95 `181.33 ms`, p99 `214.85 ms`
- Stage C config: `2 rounds x 100 concurrent` (`200` requests)
  - Outcomes: `200=2`, `409=198`, `other=0`, `one-winner rounds=2/2`
  - Latency: avg `139.64 ms`, p50 `135.44 ms`, p95 `184.52 ms`, p99 `193.26 ms`
- Stage D config: `10 rounds x 100 concurrent` (`1000` requests)
  - Outcomes: `200=10`, `409=990`, `other=0`, `one-winner rounds=10/10`
  - Latency: avg `251.87 ms`, p50 `127.24 ms`, p95 `1388.63 ms`, p99 `1403.75 ms`
- Post-check: target ride remains single-winner accepted with non-null `accepted_at`.
- Interpretation: no duplicate winner observed through stress tiers up to 100 concurrent accepts and 1,000 total accept attempts.

### Chaos validation executed

- Test: Redis fault injection via invalid secret (`heycaby/REDIS_URL`) + forced ECS restart (`desired-count 0 -> 1`)
- Expected behavior: strict fail-closed readiness when Redis unavailable
- Observed failure signal:
  - `HTTP/1.1 503 Service Unavailable`
  - payload: `{"redis":"disabled","redis_required":true,"status":"degraded","strict":true,...}`
- Recovery:
  - Restored real `rediss://...` value in Secrets Manager
  - Forced new ECS deployment
  - Readiness recovered to `HTTP/1.1 200 OK` with `redis:"ok"` and `strict:true`

## 5) Redis Lock Validation

### Implemented contract

- Lock key: `ride:<ride_id>:accept_lock`
- Lock operation: Redis `SET NX EX 15` (`SetNX` in Go Redis client)
- Order:
  1. Driver accept hits Go endpoint
  2. Redis lock attempted first
  3. If lock fail -> reject as already accepted
  4. If lock success -> DB conditional assign (`status in (pending,searching)`)

### Runtime validation

- ECS runtime now reports: Redis connected.
- `/health/ready` strict payload reports:
  - `redis: "ok"`
  - `redis_required: true`
- Concurrency simulation (live, rerun after accepted_at fix):
  - 20 concurrent accepts against same ride
  - Results: 1 success, 19 conflict, 0 other errors
  - Final DB row: one accepted winner only, with `accepted_at` timestamp set.

### Remaining validation

- Must run race harness and store result artifact proving:
  - exactly 1 success
  - N-1 conflict responses
  - single final winner in DB.

## 6) DB Constraint Validation

### Verified by metadata query

- `ride_requests` has:
  - primary key
  - multiple FK constraints (driver, rider, city/zone references)
  - status/payment/assignment checks
- `rides` has:
  - primary key
  - FK to `ride_requests`
  - FK to `drivers`

### Required next checks

- Add direct SQL assertions for:
  - one active assignment per ride request
  - no duplicate active ride ownership per driver (if business rule requires)
  - status transition guardrails at DB/service boundary
  - null/foreign key failures produce expected errors

---

## Immediate Next Commands (Suggested)

1. Add SQL post-check:
   - one winner row in `ride_requests`
   - no duplicate accepted assignments for same ride.
2. Scale load to target profile (1k rides / 10k drivers) and export full latency/error metrics.
3. Add dedicated endpoint tests if scheduled/marketplace-specific accept APIs are introduced.

## 7) Staging-First Full Scale Plan (Selected)

- Decision: run the true `1k rides / 10k drivers` profile in staging first (avoid synthetic auth/user seeding in production).
- Harness added: `scripts/load_dispatch_scale.py`
  - Supports optional synthetic seeding (`--seed-synthetic`) via Supabase Admin API.
  - Seeds auth users + drivers, posts heartbeats, runs rider nearby-supply load, computes p50/p95/p99 and radius violations.
  - Supports cleanup (`--cleanup-synthetic`) for staged test data.
- Safe validation in current env:
  - Run without seeding returned:
    - `error: insufficient_existing_available_drivers`
    - `requested: 10000`
    - `available: 0`
- Staging execution command (recommended):
  - `python3 scripts/load_dispatch_scale.py --api-base "<staging-alb>" --drivers 10000 --rides 1000 --seed-synthetic --cleanup-synthetic`

## 8) Deferred Pre-Launch Gate (Approved)

Status: **Deferred intentionally until staging Supabase exists; not blocking current feature work.**

### Deferred items (must pass before launch)

1. **True scale dispatch simulation**
   - Run `1k rides / 10k drivers` in staging using `scripts/load_dispatch_scale.py`.
   - Required outputs:
     - p50/p95/p99 nearby-supply latency
     - `duplicate_assignment_count == 0`
     - `radius_violation_count == 0`

2. **Supabase fault-injection chaos**
   - Validate fail-safe behavior during Supabase timeout/error scenarios.
   - Confirm no ghost rides and no duplicate winners after recovery.

3. **Final pre-launch sign-off artifact**
   - Update this doc with final pass/fail + metric evidence.
   - Explicitly mark launch gate as passed only after items (1) and (2).

### Safe scope allowed now

- Continue bounded lock contention tests already validated (20/50/100 and 1000-attempt race).
- Continue Redis strict fail-closed checks.
- Prioritize app/product readiness tasks while staging infra/data is prepared.

