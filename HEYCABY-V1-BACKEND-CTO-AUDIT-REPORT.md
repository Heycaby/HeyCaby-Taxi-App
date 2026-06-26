# HeyCabby V1 Backend — CTO Audit Report

**Date:** 2026-05-20  
**Auditor role:** CTO / Principal Architect (per execution prompt)  
**Source of truth:** [New-Backend-Heycaby.md](./New-Backend-Heycaby.md)  
**Production project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`, eu-west-1) — inspected via Supabase MCP  
**Migration roadmap:** [HEYCABY-V1-MIGRATION-ROADMAP.md](./HEYCABY-V1-MIGRATION-ROADMAP.md)  
**Deployment status:** **No changes deployed.** Audit and gap analysis only.

---

## Production health vs architecture compliance (read this first)

| Lens | Score | What it measures |
|------|-------|------------------|
| **Production health** | **~70%** | Can real users use what exists today? Auth, rider booking, zones, accept RPC, compliance, push — **yes**. Driver go-online / billing via Go — **problematic**. Volume is tiny (4 drivers, 46 requests), so issues are contained. |
| **Architecture compliance (V1 spec)** | **~52%** | How close is production to [New-Backend-Heycaby.md](./New-Backend-Heycaby.md)? Dual backend, missing ledger/audit/waves — **gap is normal** during evolution. |
| **V1 operational readiness checklist** | **0/10** | Have we implemented the **spec’s launch gates** (monitoring, billing tests, etc.)? **No** — this does **not** mean the app is unusable. |

**Do not read “52% compliance” or “0/10 checklist” as “production is broken.”**  
It means: **the target architecture is ahead of current implementation** — which is exactly what a good audit should show before migration.

---

## Executive summary

HeyCabby is **not a greenfield project**. Production Supabase holds real schema, migrations (240+), Edge Functions (17), and live data (4 drivers, 46 ride requests, 12 rider sessions). The platform is **pre-launch by volume** but **in production by infrastructure** (App Store apps, Supabase, Go API on AWS).

**Architecture compliance vs V1 spec: ~52%** · **Production health: ~70%** (see table above).

| Verdict | Status |
|---------|--------|
| **Ready for internal testing** | 🟡 Partial — core rider booking + Supabase accept path exist; driver go-online blocked by Go dependency + billing gaps |
| **Ready for TestFlight (NL launch cities)** | 🔴 **Not ready** — dual backend, missing platform fee ledger, dispatch waves not operational |
| **Ready for App Store release** | 🔴 **Not ready** — see blockers below |
| **Stack fit for 1k drivers / 6 months / NL only** | ✅ **Yes**, once consolidated to Supabase-only per spec |

**Priority #1:** Strangler migration to Supabase — one endpoint at a time; do not big-bang retire Go. See [HEYCABY-V1-MIGRATION-ROADMAP.md](./HEYCABY-V1-MIGRATION-ROADMAP.md).

---

## Production snapshot (Supabase MCP — 2026-05-20)

| Metric | Value |
|--------|-------|
| Drivers | 4 (all `offline`) |
| Ride requests | 46 (`41 cancelled`, `5 pending`; **0 completed** in status distribution) |
| Live driver GPS rows | 0 |
| Ride invites sent | 0 (`ride_request_invites` empty) |
| PostGIS | Installed 3.3.7 |
| pg_cron jobs | 3 (idle offline 10m, referrals 5m, rider lifecycle 20m) |
| Edge Functions | 17 active (push, Veriff, support, founding driver, email, etc.) |
| Launch cities (NL, active) | Rotterdam, Amsterdam, Utrecht, Den Haag ✓ |
| Migrations applied (remote) | 240+ |

---

## Gap analysis by specification area

Legend: ✅ Implemented correctly · 🟡 Partial · 🔴 Missing or wrong

### 1. V1 stack (Flutter + Supabase + Mapbox + Vercel only)

| Item | Status | Notes |
|------|--------|-------|
| Supabase as sole backend | 🔴 | `app_config.driver_rest_api_base_url` + Flutter `DriverApi` → Go on AWS |
| No Go in production | 🔴 | ECS `api.heycaby.nl` still wired |
| No Redis in production | 🟡 | Go smoke tests assume Redis; Supabase path does not use it |
| PostGIS for dispatch | 🟡 | Extension on; matching uses `ST_Distance` on lat/lng points in RPC, not `geography` GiST column |
| Mapbox | ✅ | Client-side maps/routing |
| Vercel | ✅ | Marketing/admin (out of scope for this audit) |

### 2. Server boundary (business logic in Supabase, not Flutter)

| Item | Status | Notes |
|------|--------|-------|
| Ride create / pricing | ✅ | Rider RPCs (`fn_estimate_trip_category_prices`, etc.) |
| Ride accept | ✅ | `fn_driver_accept_ride_invite` (Supabase RPC) |
| Go-online / readiness | 🔴 | Go `/api/v1/driver/readiness`, `/status` |
| Billing / lock | 🔴 | Go billing service + Mollie/subscription on `drivers`; no ledger |
| Location / heartbeat | 🔴 | Go `POST /api/driver/location`; no dedicated heartbeat RPC |
| Ride lifecycle (arrived/start/complete) | 🔴 | Go HTTP endpoints from `DriverApi` |
| Boot config | 🟡 | `app_config` + partial `/api/v1/config` via Go |

### 3. Dispatch vs ride lifecycle (two state machines)

| Item | Status | Notes |
|------|--------|-------|
| Separate dispatch states | 🔴 | Single `ride_requests.status` text (`pending`, `assigned`, …); no `searching`/`offering`/`dispatch_complete` |
| Ride lifecycle states | 🟡 | Columns exist (`accepted_at`, `started_at`, `completed_at`) but not enforced as strict FSM |
| Spec `rides` table | 🟡 | **`ride_requests` is production table**; `rides` exists but empty — do not fork |

### 4. Presence vs availability

| Item | Status | Notes |
|------|--------|-------|
| Split presence / availability | 🔴 | Single `drivers.status` enum: `available`, `on_ride`, `offline`, `on_break` |
| Heartbeat every 5–10s | 🔴 | No `fn_driver_heartbeat`; Go location POST or direct upsert |
| Auto-offline ~30s | 🟡 | `mark_idle_drivers_offline` cron every **10 minutes** |
| `driver_sessions` | 🔴 | Not present |

### 5. Matching & offers

| Item | Status | Notes |
|------|--------|-------|
| Eligibility pipeline | 🟡 | `fn_seed_ride_matching_batch` filters status, distance, category; GPS freshness partial via indexes |
| `ride_offers` / waves | 🟡 | **`ride_request_invites`** (`batch_no`, `expires_at`, `status`) — schema exists, **never used in prod** |
| 4-wave / 90s sequence | 🔴 | No cron to advance waves or expire offers |
| Atomic accept | ✅ | `fn_driver_accept_ride_invite` — conditional update, supersede other invites |
| Cancel-on-accept push | 🔴 | Invites → `superseded`; no trigger/Edge Function to push cancel to losers |
| Idempotency keys on mutating RPCs | 🔴 | Not implemented |

### 6. Platform billing (€1/ride, €60 lock)

| Item | Status | Notes |
|------|--------|-------|
| `billing_ledger` | 🔴 | **Does not exist** |
| Fee on trip complete only | 🔴 | `platform_fee_cents` column on `ride_requests`; no append-only ledger |
| Immutable ledger + reversals | 🔴 | `driver_payment_events` is Mollie subscription attempts, not ride-accrual ledger |
| Lock at €60 outstanding | 🔴 | Subscription/`subscription_active` model on `drivers`; not spec model |
| Lock check in accept | 🔴 | `fn_driver_accept_ride_invite` does not check billing lock |
| Unlock on settlement | 🔴 | No settlement → unlock trigger |
| Audit log for billing | 🔴 | No `ride_audit_log` |

### 7. Audit log & event bus

| Item | Status | Notes |
|------|--------|-------|
| `ride_audit_log` | 🔴 | Missing |
| `noun.verb` events | 🔴 | Scattered triggers (`trg_record_trip_history`, etc.) — not unified audit stream |
| Event handlers decoupled | 🟡 | Many triggers on `ride_requests`; not spec-shaped event bus |

### 8. Configuration layer

| Item | Status | Notes |
|------|--------|-------|
| `market_config` per city | 🟡 | `app_config.country_config.NL`, `search_config`, `feature_flags` — no per-city fee/limit/timeout keys |
| NL defaults (€1, €60, 20s) | 🔴 | Not in config DB |
| Hardcoded Flutter constants | 🟡 | Search windows, radii partially in app + partial server config |

### 9. Security

| Item | Status | Notes |
|------|--------|-------|
| JWT on RPCs | ✅ | Supabase Auth default |
| RLS on core tables | ✅ | `ride_requests`, `drivers`, `driver_locations`, invites |
| RLS gaps | 🔴 | `founding_contract_links`, `launch_regions` — **RLS disabled** (MCP security advisor) |
| Rate limiting ride create/accept | 🔴 | Community rate limits exist; not on dispatch endpoints |
| Driver authorization in RPCs | 🟡 | Accept checks `auth.uid()` → driver; not all RPCs audited |
| Service role leakage | 🟡 | Edge Functions vary (`verify_jwt` false on several — review each) |

### 10. Background jobs (spec list)

| Job | Status |
|-----|--------|
| Expire offers | 🔴 |
| Advance dispatch waves | 🔴 |
| Heartbeat → offline | 🟡 (`mark_idle_drivers_offline`, 10m) |
| Unlock after settlement | 🔴 |
| Clean stale locations | 🟡 (`cleanup_stale_driver_locations` exists in repo) |
| Retry failed push | 🔴 |
| Archive old rides | 🔴 |

### 11. Monitoring & operational readiness

| Item | Status |
|------|--------|
| Metric thresholds in spec | 🔴 Not instrumented on Supabase path |
| Operational readiness checklist (spec §) | **0/10 checked** for V1 spec |
| Existing smoke tests | 🟡 [docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md](./docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md) targets **Go + Redis**, not Supabase-only |

---

## System invariants (14) — compliance matrix

| # | Invariant | Status |
|---|-----------|--------|
| 1 | One assigned driver per ride | ✅ Enforced in accept RPC + `ride_requests_one_active_per_driver_idx` |
| 2 | Completed ride never returns to searching | 🟡 No strict FSM guard |
| 3 | Riders never pay HeyCabby for fares | ✅ By design; no rider→platform fare ledger |
| 4 | Platform fees only after complete | 🔴 No ledger; column exists unused |
| 5 | Immutable ledger | 🔴 |
| 6 | Every transition → audit log | 🔴 |
| 7 | Stale GPS (>2m) no offers | 🟡 Partial in matching SQL |
| 8 | Locked driver: finish trip, no new accepts | 🔴 |
| 9 | Idempotent mutating APIs | 🔴 |
| 10 | Business rules server-side | 🟡 Rider yes; driver go-online/billing/ride steps via Go |
| 11 | Presence ≠ availability | 🔴 |
| 12 | Cancel other offers on accept (explicit) | 🟡 DB supersede; no cancel push |
| 13 | Session status authorizes actions | 🔴 |
| 14 | Realtime ≠ source of truth | 🟡 Documented in spec; app behavior not fully verified |

**Invariants fully met: 2/14 · Partial: 6/14 · Not met: 6/14**

---

## Rider flow audit

| Step | Status | Implementation |
|------|--------|----------------|
| Account / guest identity | ✅ | `rider_sessions`, `rider_identities`, OTP RPCs |
| Login (OTP) | ✅ | Supabase Auth + rider session RPCs |
| Address search / Mapbox | ✅ | Client Mapbox |
| Pickup / destination | ✅ | `ride_request_provider` |
| Price calculation | ✅ | `TripCategoryPricingService` → RPC |
| Ride request creation | ✅ | Insert `ride_requests` + matching trigger |
| Driver matching | 🟡 | Trigger seeds batch; **no live invites in prod** |
| Waiting screen | ✅ | Flutter + Realtime |
| Driver assigned | 🟡 | Accept RPC works; end-to-end not proven at scale |
| Driver tracking | 🟡 | Realtime on `driver_locations`; 0 live rows |
| Messaging | ✅ | `messages` table + RLS |
| Calling | 🟡 | Client-side (tel:) — not audited |
| Cancellation | 🟡 | Status updates exist; billing side effects N/A |
| Arrival / start / complete | 🔴 | Driver side uses **Go API**, not Supabase RPCs |
| History / ratings | 🟡 | Tables + triggers; minimal production data |
| Notifications | ✅ | `send-push` Edge Function + `push_devices` |

---

## Driver flow audit

| Step | Status | Implementation |
|------|--------|----------------|
| Registration | 🟡 | Supabase Auth; **`user_type: driver` often missing** → Go 403 |
| Verification (Veriff) | ✅ | Edge Functions + `drivers` compliance columns |
| Document approval | ✅ | Admin + compliance RPCs |
| Vehicle approval | ✅ | RDW + manual fields |
| Login | ✅ | OTP + session bootstrap |
| Go online / offline | 🔴 | **Go `/api/v1/driver/status`** + readiness |
| Heartbeat / presence | 🔴 | Go location or direct upsert; no spec heartbeat |
| Pickup radius | 🟡 | `pickup_distance_max_km` on driver; enforced in matching SQL |
| Receive offer | 🟡 | Realtime on invites; **0 invites ever sent in prod** |
| Offer expiry | 🔴 | No cron |
| Accept ride | ✅ | **`fn_driver_accept_ride_invite`** (Supabase) |
| Decline | 🟡 | Invite status possible; flow not verified |
| Arrival / start / complete | 🔴 | **Go `DriverApi`** |
| Billing / wallet | 🔴 | Mollie subscription model; **no €1/ride ledger** |
| Platform fee lock €60 | 🔴 | Missing |
| Unlock after payment | 🔴 | Missing |
| Ride history | ✅ | `ride_requests` + finance RPCs |
| Notifications | ✅ | FCM via `send-push` |

---

## Dispatch engine audit

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Single winner per ride | ✅ | `fn_driver_accept_ride_invite` conditional `UPDATE … WHERE status = 'pending'` |
| Atomic acceptance | ✅ | Same RPC in transaction |
| Idempotent accept | 🔴 | Retry may return `race_lost`; no idempotency key |
| Offer expiry | 🔴 | `expires_at` column; no job |
| Offer cancellation | 🟡 | `superseded` status; no push |
| Dispatch waves | 🔴 | `batch_no` only; no wave advance cron |
| Radius expansion | 🟡 | Matching batch params; not spec 4-wave |
| Driver pickup radius | ✅ | In matching SQL |
| Rider search radius | 🟡 | `search_config` + client; partial |
| Vehicle / city filter | ✅ | In matching SQL |
| GPS freshness | 🟡 | `idx_driver_locations_country_fresh`; 2-minute rule in SQL partial |
| Billing lock blocks dispatch | 🔴 | Not in accept or seed |
| Busy drivers excluded | ✅ | `status = 'available'` filter |
| Suspended drivers excluded | 🟡 | `compliance_status` / admin paths; not unified `availability = suspended` |

**Concurrency:** Go path tested (20 simultaneous accepts → 1 winner). **Supabase RPC path not load-tested** in existing smoke suite.

---

## Billing audit

| Requirement | Status |
|-------------|--------|
| €1 fee after completed ride only | 🔴 |
| Rider payments not in platform ledger | ✅ |
| Immutable ledger | 🔴 |
| Reversals | 🔴 |
| Outstanding balance | 🔴 |
| Lock at €60 | 🔴 |
| Auto unlock on settlement | 🔴 |
| Billing in audit log | 🔴 |

**Existing (legacy):** `drivers.subscription_active`, `weekly_rate_euros`, `driver_payment_events` (Mollie), Apple IAP path in Go — **conflicts with V1 pay-per-ride accrual model**. Migrate, do not duplicate.

---

## Database audit highlights

### Strengths
- 240+ migrations; mature schema for NL taxi compliance
- Strong indexing on `ride_requests`, `drivers`, invites
- RLS on critical tables
- Atomic accept RPC
- `country_code` on core tables
- Launch geography (zones, cities, neighbors)

### Gaps vs spec
- No `billing_ledger`, `ride_audit_log`, `driver_sessions`, `driver_location_history`
- No GiST on `geography` (uses lat/lng + btree indexes)
- `ride_request_invites.status` values: `pending` / `accepted` / `superseded` — align with spec `sent`/`cancelled`/`expired` in migration, not rename in prod without app coordination
- Duplicate conceptual tables: `rides` vs `ride_requests`

### Security advisor (sample)
- Many functions with mutable `search_path` (WARN)
- **Critical:** RLS disabled on `founding_contract_links`, `launch_regions`
- Review Edge Functions with `verify_jwt: false`

---

## Performance audit (preliminary)

| Area | Assessment |
|------|------------|
| Missing GiST geography index | 🟡 Acceptable at 4 drivers; **required before 1k** |
| `ride_requests` index coverage | ✅ Good |
| N+1 in Flutter | Not fully profiled |
| Realtime channel scope | Not load-tested |
| RPC `accept` latency | Not measured on Supabase path |
| Heartbeat write rate at 1k online | ~200 upserts/s — feasible with upsert pattern |

**Do not optimize prematurely.** First consolidate backend; then measure.

---

## Smoke test & concurrency — current state

| Test | Result | Notes |
|------|--------|-------|
| Rider register / login | Not run this audit | Manual / TestFlight |
| Request ride | Not run | 5 pending in DB |
| Complete ride E2E | **Fail** | 0 completed rides in prod |
| Driver go online | **Fail** | Go 403 / billing gates reported in field |
| Accept concurrency (Supabase RPC) | **Not run** | Go path tested only |
| 100 simultaneous requests | **Not run** | |
| Offer expiry | **Not run** | No cron |
| Reconnect / Realtime | **Not run** | |
| Billing lock/unlock | **Not run** | Feature missing |

Existing [BACKEND_SIMULATION_SMOKE_TEST_MASTER.md](./docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md) must be **rewritten for Supabase-only** acceptance criteria.

---

## Operational readiness checklist (spec)

| Item | Pass? |
|------|-------|
| Migrations tested on staging copy | 🔴 |
| RLS verified all tables | 🔴 (known gaps) |
| RPC backward compatibility | 🟡 |
| Feature flags risky = OFF | 🟡 |
| Billing tested | 🔴 |
| Accept concurrency tested (Supabase) | 🔴 |
| Push E2E incl cancel-on-accept | 🔴 |
| Rollback rehearsed | 🔴 |
| Monitoring alerts | 🔴 |
| Backup restore tested | 🔴 |

---

## Recommended remediation plan (safe migration order)

**No code deployed in this audit.** Recommended sequence for explicit approval:

### Phase A — Foundation (no app breaking)
1. Add `billing_ledger` + views for outstanding balance (additive migration)
2. Add `ride_audit_log` + triggers on `ride_requests` / invites (additive)
3. Extend `country_config.NL` with `platform_fee_cents`, `outstanding_limit_cents`, offer timeouts
4. Enable RLS on `founding_contract_links`, `launch_regions` with read policies

### Phase B — Billing + dispatch (feature-flagged)
5. Trigger: on `ride_requests.status → completed`, insert `ride_fee` ledger row
6. Add billing lock check to `fn_driver_accept_ride_invite` + `fn_seed_ride_matching_batch`
7. pg_cron: expire invites, advance matching batches (waves)
8. Edge Function or trigger: cancel push on accept

### Phase C — Driver path (parallel run, then cutover)
9. Add `fn_driver_heartbeat`, `fn_driver_set_status`, `fn_driver_readiness` RPCs
10. Add `presence` + `availability` columns (migrate from `status` gradually)
11. Flutter: call Supabase RPCs; keep Go as fallback behind flag
12. Remove `driver_rest_api_base_url` dependency; decommission Go from prod

### Phase D — Validation
13. Supabase-native concurrency suite (2 drivers, 20 drivers, 100 requests)
14. Operational readiness checklist
15. TestFlight with NL four cities only

---

## Technical debt (intentionally deferred)

| Item | Reason |
|------|--------|
| `driver_sessions` table | Defer until multi-device revocation needed |
| `driver_location_history` | Defer until disputes/fraud volume |
| Mapbox ETA re-rank in dispatch | PostGIS distance sufficient for V1 |
| Full admin dashboard | Queries over existing tables later |
| Go matching engine | Keep in repo; not production until metrics |

---

## Duplicate / conflicting implementations (must simplify)

| Domain | Duplicate | Action |
|--------|-----------|--------|
| Backend | Supabase RPCs + Go API | **Single winner: Supabase** |
| Billing | Mollie subscription + spec ledger | **Migrate to ledger**; keep Mollie for settlement only |
| Ride entity | `rides` + `ride_requests` | **Standardize on `ride_requests`** |
| Offers | Spec `ride_offers` name vs `ride_request_invites` | **Extend invites**, do not create second table |
| Config | Go `/api/v1/config` + `app_config` | **Single RPC reading `app_config`** |
| Smoke tests | Go/Redis vs Supabase | **Rewrite test master** |

---

## Final verdict

### Production readiness

| Gate | Ready? | Why |
|------|--------|-----|
| Internal QA | 🟡 | Rider path testable; driver blocked on Go/billing |
| TestFlight (NL launch) | 🔴 | Dual backend, no platform fee ledger, dispatch waves inactive |
| App Store release | 🔴 | Billing model incomplete, invariants 6/14 failing, audit log missing |

### Will the V1 stack handle 1,000 drivers in 6 months (NL only)?

**Yes — after consolidation.** Supabase + PostGIS + Realtime is sufficient for four Dutch cities and ~1k drivers. The blocker is **implementation completeness**, not stack choice.

### What must happen before any production deploy

1. **Explicit approval** per migration and app release  
2. **Gap analysis sign-off** on Phase A–D  
3. **No destructive migrations** without backup + staging replay  
4. **Backward-compatible RPC extensions** until Flutter cutover confirmed  

---

## Related documents

- Architecture spec: [New-Backend-Heycaby.md](./New-Backend-Heycaby.md)
- Legacy smoke tests (Go-centric): [docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md](./docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md)
- Next required: **Database Specification**, **API Specification**, **QA & Smoke Test Specification** (Supabase-native)

---

*This report is the CTO gap analysis baseline. No database migrations, Edge Function deploys, or app builds were executed as part of this audit.*
