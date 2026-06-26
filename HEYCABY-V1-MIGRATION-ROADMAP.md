# HeyCabby V1 Migration Roadmap

**Date:** 2026-05-20  
**Owner:** CTO / Engineering  
**Source of truth:** [New-Backend-Heycaby.md](./New-Backend-Heycaby.md)  
**Baseline audit:** [HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md](./HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md)  
**Strategy:** **Strangler migration** — one endpoint at a time; Go stays until each Supabase path is proven.  
**Deploy rule:** No migration applied to production without explicit approval, staging replay, and smoke tests.

---

## Production health vs architecture compliance

These are **different measurements**. Do not conflate them.

| Lens | Question | Current score | Meaning |
|------|----------|---------------|---------|
| **Production health** | Does the existing app work for real users today? | **~70% functional** | Rider booking, auth, compliance, accept RPC, manual rides, push, zones/cities exist. Driver path **partially blocked** (Go go-online/billing 403 class issues). Low volume (4 drivers, 46 requests) limits blast radius. |
| **Architecture compliance** | Does production match **New-Backend-Heycaby.md**? | **~52%** | Dual backend, no billing ledger, no audit log, dispatch waves inactive, presence/heartbeat not spec-shaped. |
| **Operational readiness (V1 spec checklist)** | Are all 10 launch gates from the spec passed? | **0/10** | Measures **V1 spec implementation**, not “app is broken.” |

**Summary:** The production system is **evolving and usable in parts**, not a greenfield failure. The audit score reflects **distance to target architecture**, not total product collapse.

---

## Executive migration strategy

### Phasing (CTO-approved order)

| Phase | Focus | Risk | Rationale |
|-------|--------|------|-----------|
| **1** | Audit log | **Low** | Every subsequent change is traceable; build once |
| **2** | Billing ledger (€1/ride, €60 lock) | **Low–Medium** | Additive; legacy subscription fields remain until cutover |
| **3** | Dispatch waves | **High** | Prove matching E2E; invites table exists but unused |
| **4** | Presence + heartbeat | **Medium** | Reliability after dispatch works |
| **5** | Strangler: Go → Supabase RPCs | **Medium–High** | One endpoint per week; parallel paths behind flags |
| **6** | Decommission Go (production traffic) | **High** | Only when matrix shows **Complete** for all P0 rows |

### Strangler pattern (mandatory)

```
Today (dual path allowed during migration):

  Flutter ──feature flag──► Supabase RPC (new)
         └──fallback──────► Go API (legacy, until row = Complete)

Target (end state):

  Flutter ────────────────► Supabase RPC / Edge Function only
```

**Never** big-bang turn off Go. Clear `app_config.driver_rest_api_base_url` only when the migration matrix P0 rows are **Complete** and TestFlight smoke passes.

---

## Migration matrix (live checklist)

Status key: **Complete** · **In progress** · **Pending** · **Partial** · **Blocked**

| # | Feature | Current | Target | Risk | Phase | Status |
|---|---------|---------|--------|------|-------|--------|
| M1 | Ride accept (atomic) | Supabase `fn_driver_accept_ride_invite` | Same + billing lock + audit | Low | 2–3 | **Partial** |
| M2 | Ride decline | Go `/api/driver/ride/decline` (fallback paths) | Supabase RPC on `ride_request_invites` | Medium | 3 | Pending |
| M3 | Rider create ride | Supabase insert + matching trigger | Same + audit + rate limit | Low | 1–3 | Partial |
| M4 | Dispatch batch / invites | `fn_seed_ride_matching_batch` + `ride_request_invites` | + wave cron + expiry + cancel push | High | 3 | Partial |
| M5 | Dispatch waves (4-wave / 90s) | Trigger only batch 1 | pg_cron advance + radius expand | High | 3 | Pending |
| M6 | Offer expiry | Column `expires_at`; no job | pg_cron expire invites | Medium | 3 | Pending |
| M7 | Cancel-on-accept push | DB `superseded` only | Edge `send-push` to losers | Medium | 3 | Pending |
| M8 | Audit log | Missing | `ride_audit_log` + triggers | Low | 1 | Pending |
| M9 | Platform billing ledger | `platform_fee_cents` column; Mollie subs | `billing_ledger` accrual | Medium | 2 | Pending |
| M10 | Billing lock (€60) | Go/subscription gates | Ledger sum + `availability=locked` | Medium | 2 | Pending |
| M11 | Billing settlement | Go Mollie + Apple IAP | Edge webhook + ledger `settlement` | Medium | 2–5 | Pending |
| M12 | Go online / readiness | Go `/api/v1/driver/readiness`, `/status` | `fn_driver_readiness`, `fn_driver_set_status` | Medium | 5 | Pending |
| M13 | Driver heartbeat / location | Go `/api/driver/location` | `fn_driver_heartbeat` → `driver_locations` | Medium | 4–5 | Pending |
| M14 | Presence vs availability | Single `drivers.status` enum | `presence` + `availability` columns | Medium | 4 | Pending |
| M15 | Auto-offline (ghost drivers) | `mark_idle_drivers_offline` every 10m | Heartbeat + 30s threshold cron | Medium | 4 | Pending |
| M16 | Ride arrived | Go `/api/driver/ride/arrived` | `fn_driver_ride_arrived` RPC | Medium | 5 | Pending |
| M17 | Trip start | Go `/api/driver/ride/start` | `fn_driver_ride_start` RPC | Medium | 5 | Pending |
| M18 | Trip complete | Go `/api/driver/ride/complete` | `fn_driver_ride_complete` RPC + billing trigger | Medium | 5 | Pending |
| M19 | Ride cancel (driver) | Go cancel variants | `fn_driver_ride_cancel` RPC | Medium | 5 | Pending |
| M20 | Manual street ride | Supabase `fn_driver_create_manual_ride` | Same + audit | Low | 1 | Partial |
| M21 | Rider pricing | Supabase RPCs | Same + config-driven | Low | — | **Complete** |
| M22 | Boot / runtime config | Go `/api/v1/config` + `app_config` | `fn_get_boot_config` RPC | Low | 5 | Partial |
| M23 | Rider nearby supply | Go `/api/v1/rider/nearby-supply` | PostGIS RPC / extend `get_nearby_drivers` | Medium | 5 | Partial |
| M24 | Driver JWT role | Missing `user_type` on some accounts | Signup + `ensureDriverJwtUserType` | Low | 5 | Partial |
| M25 | RLS gaps | `founding_contract_links`, `launch_regions` open | RLS + policies | Low | 1 | Pending |
| M26 | Idempotency keys | None on mutating RPCs | `idempotency_key` param + table | Medium | 3–5 | Pending |
| M27 | Go production traffic | `driver_rest_api_base_url` active | Null / deprecated | High | 6 | Pending |
| M28 | Smoke test suite | Go+Redis master doc | Supabase-native QA spec | Medium | 6 | Pending |

---

## Detailed migration cards

Each card: **current → target**, changes, risk, effort, tests, rollback.

---

### M8 — Audit log (Phase 1 · Priority first)

| Field | Detail |
|-------|--------|
| **Current** | No unified audit; scattered triggers (`trg_record_trip_history`, earnings bumps, etc.) |
| **Target** | `ride_audit_log` (insert-only); `event` = `noun.verb`; every dispatch + lifecycle transition |
| **Database** | `CREATE TABLE ride_audit_log (...)`; triggers on `ride_requests`, `ride_request_invites`, `drivers` status changes |
| **RPC** | Optional `fn_audit_append(ride_id, event, metadata)` SECURITY DEFINER helper |
| **RLS** | SELECT own rides (driver/rider); admin role SELECT all; INSERT via triggers only |
| **Flutter** | None initially; admin/support viewer later |
| **Edge Functions** | None |
| **Risk** | **Low** — additive only |
| **Effort** | **S** (2–3 days) |
| **Smoke tests** | Insert ride → pending; accept → `offer.accepted`; complete → `trip.completed`; verify row count |
| **Rollback** | Drop triggers; retain table (never delete audit data) |

---

### M9 / M10 — Billing ledger + lock (Phase 2)

| Field | Detail |
|-------|--------|
| **Current** | `drivers.subscription_*`, `driver_payment_events` (Mollie); Go billing service; `platform_fee_cents` on `ride_requests` |
| **Target** | Immutable `billing_ledger`; +€1 `ride_fee` on complete; outstanding view; lock at €6000 cents (€60) |
| **Database** | `billing_ledger`; view `driver_platform_balance`; trigger on complete; **extend** `fn_driver_accept_ride_invite` + `fn_seed_ride_matching_batch` to reject locked drivers |
| **RPC** | `fn_driver_platform_balance`; `fn_settle_platform_fees` (creates settlement row + clears lock) |
| **RLS** | Driver SELECT own ledger; INSERT trigger/service only |
| **Flutter** | Dashboard: “Outstanding platform fees”; replace subscription gate UI with balance (keep Mollie/IAP behind settlement RPC) |
| **Edge Functions** | Mollie webhook → `fn_settle_platform_fees`; Apple verify → settlement (Phase 2b) |
| **Config** | Add to `country_config.NL`: `platform_fee_cents: 100`, `outstanding_limit_cents: 6000` |
| **Risk** | **Medium** — must not double-charge with legacy subscription |
| **Effort** | **M** (5–7 days) |
| **Smoke tests** | Complete 60 rides → locked; settle → unlocked; accept while locked → error; manual adjustment reversal |
| **Rollback** | Feature flag `billing_ledger_enabled`; disable triggers; keep Go subscription gate until stable |

**Legacy coexistence:** Do **not** remove `subscription_active` until ledger path proven in TestFlight.

---

### M4 / M5 / M6 / M7 — Dispatch waves (Phase 3)

| Field | Detail |
|-------|--------|
| **Current** | `trg_ride_request_after_insert_matching` → `fn_seed_ride_matching_batch(id, 4, 30)`; **0 invites in prod** |
| **Target** | 4-wave / ~90s sequence; expire; expand radius; cancel push on accept |
| **Database** | Extend `ride_request_invites` if needed (`wave` alias `batch_no`); status align `sent`/`expired`/`cancelled` |
| **RPC** | `fn_advance_ride_matching_waves()`; `fn_expire_ride_invites()` |
| **Cron** | pg_cron every 10–15s for expiry; every 20s for wave advance (tune in staging) |
| **Edge Functions** | `send-push` on invite; on accept call notify losers |
| **Flutter** | Rider waiting UI reflects wave state; driver offer TTL from server |
| **Risk** | **High** — core marketplace path |
| **Effort** | **L** (7–10 days) |
| **Smoke tests** | 1 rider / 5 drivers; no accept → 4 waves → fail; 1 accept → others cancelled + push; concurrent accept |
| **Rollback** | Flag `dispatch_waves_v2_enabled=false`; revert to single-batch trigger only |

---

### M14 / M15 — Presence + heartbeat (Phase 4)

| Field | Detail |
|-------|--------|
| **Current** | `drivers.status` enum; Go location POST; idle cron 10m |
| **Target** | `presence` + `availability`; heartbeat every 5–10s; offline at ~30s miss |
| **Database** | ADD columns `presence`, `availability`, `last_heartbeat_at`; migrate from `status` via one-time backfill |
| **RPC** | `fn_driver_heartbeat(lat, lng, heading)` — upsert location + touch heartbeat |
| **Cron** | Replace/supplement `mark_idle_drivers_offline` with 30s threshold job |
| **Flutter** | Timer calling heartbeat RPC instead of Go location when flag on |
| **Risk** | **Medium** — drivers may flicker offline if interval wrong |
| **Effort** | **M** (4–6 days) |
| **Smoke tests** | Online → heartbeat stops → offline <60s; on_ride → availability busy, presence online |
| **Rollback** | Flag `heartbeat_v1_enabled`; fall back to Go location + old cron |

---

### M12 — Go online / readiness (Phase 5 · Strangler week 1)

| Field | Detail |
|-------|--------|
| **Current** | Go `GET /api/v1/driver/readiness`, `POST /api/v1/driver/status`; Flutter `DriverRuntimeService` |
| **Target** | `fn_driver_readiness()` → JSON checklist; `fn_driver_set_status(status)` |
| **Database** | Readiness logic in RPC (compliance, billing lock, documents); reuse existing compliance columns |
| **Flutter** | `driver_runtime_service.dart` try RPC first, Go fallback via `FeatureFlags.useSupabaseDriverRuntime` |
| **Risk** | **Medium** — blocked TestFlight path |
| **Effort** | **M** (4–5 days) |
| **Smoke tests** | Go online; on_break; end shift; readiness blocked when locked |
| **Rollback** | Flag off → Go only |

---

### M16 / M17 / M18 — Ride lifecycle (Phase 5 · Strangler weeks 3–5)

| Endpoint (Go today) | Target RPC | Billing hook |
|---------------------|------------|--------------|
| `POST /api/driver/ride/arrived` | `fn_driver_ride_arrived` | Audit only |
| `POST /api/driver/ride/start` | `fn_driver_ride_start` | Audit only |
| `POST /api/driver/ride/complete` | `fn_driver_ride_complete` | Audit + **ledger ride_fee** |

| Field | Detail |
|-------|--------|
| **Flutter** | `DriverApi.markArrived/startRide/completeRide` → RPC when flag on |
| **Risk** | **Medium** — must match Go state transitions for in-flight rides |
| **Effort** | **M** each (3 days × 3) |
| **Smoke tests** | Full trip E2E on Supabase path; billing row on complete only |
| **Rollback** | Per-endpoint flag |

---

### M22 / M23 — Rider config & nearby (Phase 5)

| Field | Detail |
|-------|--------|
| **Current** | Go `/api/v1/config`, `/api/v1/rider/nearby-supply` |
| **Target** | `fn_get_boot_config`; extend `fn_get_nearby_drivers_by_category` or new RPC |
| **Flutter** | `rider_runtime_config_service.dart`, `nearby_supply_service.dart` |
| **Risk** | **Low–Medium** |
| **Effort** | **S–M** (3–4 days) |

---

### M27 — Go decommission (Phase 6)

| Field | Detail |
|-------|--------|
| **Preconditions** | M1–M26 P0 rows **Complete**; 2 weeks TestFlight without Go fallback |
| **Actions** | Set `driver_rest_api_base_url` empty; remove Dio interceptors from hot path; keep Go repo for future |
| **Risk** | **High** if rushed |
| **Rollback** | Restore `app_config` URL; re-enable flags |

---

## Week-by-week strangler schedule (suggested)

| Week | Deliverable | Matrix rows |
|------|-------------|-------------|
| 1 | Audit log live (staging → prod) | M8, M25 |
| 2 | Billing ledger + balance view (no lock yet) | M9 |
| 3 | Billing lock in accept + matching | M10 |
| 4–5 | Dispatch waves + expiry + cancel push | M4–M7 |
| 6 | Presence/heartbeat (staging) | M14–M15 |
| 7 | Strangler: readiness + set_status | M12 |
| 8 | Strangler: heartbeat replaces Go location | M13 |
| 9 | Strangler: arrived + start | M16–M17 |
| 10 | Strangler: complete + billing trigger wired | M18 |
| 11 | Rider boot config + nearby RPC | M22–M23 |
| 12 | TestFlight soak; disable Go fallback | M27 |
| 13+ | Remove Go from prod config | M27 |

Adjust based on team size. **Do not compress Phase 3 and Phase 5 into the same week.**

---

## Smoke tests required (Supabase-native master list)

Replace [docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md](./docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md) with these as each phase ships.

### Phase 1 — Audit
- [ ] Ride create writes `ride.created`
- [ ] Accept writes `offer.accepted`
- [ ] Admin can query timeline by `ride_id`

### Phase 2 — Billing
- [ ] Complete ride → one `ride_fee` ledger row
- [ ] 60 completes → driver locked
- [ ] Settlement → unlock + `settlement` row
- [ ] Reversal via `manual_adjustment` + opposite amount

### Phase 3 — Dispatch
- [ ] 1 rider / 1 driver → assign
- [ ] 1 rider / 5 drivers → 1 winner, 4 cancelled
- [ ] No driver → 4 waves → rider fail message
- [ ] 20 concurrent accepts → 1 success (Supabase RPC, not Go)

### Phase 4 — Presence
- [ ] Heartbeat stop → offline <60s
- [ ] Busy driver excluded from new offers

### Phase 5 — Strangler E2E
- [ ] Full ride on Supabase path only (no Go calls in network log)
- [ ] Go online → accept → arrive → start → complete → fee accrued

### Phase 6 — Cutover
- [ ] Production with empty `driver_rest_api_base_url`
- [ ] Legacy app version still works (RPC v1 compatibility)

---

## Rollback principles (every phase)

1. **Feature flags** in `app_config.feature_flags` — server-side, default OFF for risky paths.
2. **Additive migrations only** until Phase 6; never drop Go-required columns early.
3. **Dual-write audit** optional for billing (ledger + legacy column) during Phase 2 soak.
4. **Restore `driver_rest_api_base_url`** — instant Go fallback for driver app without new IPA if RPC flags off.
5. **Never delete** `billing_ledger` or `ride_audit_log` rows on rollback.

---

## Effort summary

| Phase | Focus | Calendar (1 senior + support) |
|-------|--------|-------------------------------|
| 1 | Audit log + RLS fixes | ~1 week |
| 2 | Billing ledger + lock | ~2 weeks |
| 3 | Dispatch waves | ~2 weeks |
| 4 | Presence / heartbeat | ~1 week |
| 5 | Strangler Go endpoints | ~5 weeks |
| 6 | Cutover + QA doc | ~2 weeks |
| **Total** | | **~13 weeks** to V1-compliant Supabase-only prod |

Parallel Flutter work can overlap Phase 5.

---

## Document links

| Document | Purpose |
|----------|---------|
| [New-Backend-Heycaby.md](./New-Backend-Heycaby.md) | Target architecture |
| [HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md](./HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md) | Gap analysis baseline |
| **This file** | Execution roadmap + live matrix |
| *TBD* | Database Specification |
| *TBD* | API Specification |
| *TBD* | QA & Smoke Test Specification (Supabase-native) |

---

## Approval gate before first migration

- [ ] Stakeholder sign-off on phasing (audit → billing → waves → presence → strangler)
- [ ] Staging project or branch verified for migration replay
- [ ] Backup restore tested on HEYCABY-TAXI
- [ ] Feature flag keys named in `app_config.feature_flags`
- [ ] Explicit **“approve Phase 1 migration”** from product owner

**No SQL applied to production until the above are checked.**

---

*Migration matrix status should be updated in this file after each shipped phase.*
