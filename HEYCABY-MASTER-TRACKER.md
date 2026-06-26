# HeyCabby Master Tracker

**Single daily source of truth.** Update this file after every migration — not new architecture docs.

| Reference (frozen) | Link |
|------------------|------|
| Architecture spec | [New-Backend-Heycaby.md](./New-Backend-Heycaby.md) |
| Audit baseline | [HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md](./HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md) |
| Migration detail | [HEYCABY-V1-MIGRATION-ROADMAP.md](./HEYCABY-V1-MIGRATION-ROADMAP.md) |

**Planning phase:** ✅ Frozen (2026-05-20)  
**Execution rule:** 80% implementation · 20% documentation  
**Deploy rule:** Nothing to production without explicit approval + PRR + all four checkboxes below.

**TRB (company policy):** [docs/TECHNICAL-REVIEW-BOARD.md](./docs/TECHNICAL-REVIEW-BOARD.md)  
**Platform Playbook:** [docs/PLATFORM-PLAYBOOK.md](./docs/PLATFORM-PLAYBOOK.md)  
**Engineering maturity:** **Level 4 — Governed** (Level 5 after Programs 2–5)

--- No single deploy may change both business rules **and** user-visible behaviour. M10A = expose only · M10B = dispatch filter · M10C = accept reject.

**Rule lifecycle principle (CTO):** Every new business rule must first exist as an observable capability before it becomes an enforced rule — **Expose → Observe → Measure → Enforce**.

**Engineering Bible:** [docs/ENGINEERING-BIBLE.md](./docs/ENGINEERING-BIBLE.md) — permanent principles, program roadmap, subsystem completion checklist.

---

## Company program roadmap

| Program | Status | Notes |
|---------|--------|-------|
| **Foundation** | ✅ Complete · LTS | Audit, RLS, market_config (M8, M25, Phase 2 schema) |
| **Billing** | ✅ Complete · LTS | M9–M10C frozen |
| **Driver Connectivity** | 🟡 **M14 observation** | RC2 approved · flag off · observe only until ~2026-05-21 |
| **Dispatch Intelligence** | ⏳ Planned | After P2 stable |
| **Backend Consolidation** | ⏳ Planned | Go strangler |
| **Observability** | ⏳ Planned | Program 5 |
| **Production Scale** | ⏳ Planned | After P1–P5 |

Program 1 delivered **Foundation** and **Billing** — preserved separately in history.

---

## Programs (numbered — legacy tracker)

| # | Program | Status | Goal |
|---|---------|--------|------|
| **1** | Foundation + Billing | ✅ **LTS** | 100% |
| **2** | Driver Connectivity | 🟡 **M14 observation** | ~25% |
| **3** | Dispatch Intelligence | ⏳ Planned | 100% |
| **4** | Backend Consolidation | ⏳ Planned | 100% |
| **5** | Observability | ⏳ Planned | 100% |
| **6** | Production Scale | ⏳ Planned | 100% |

Closure: [PROGRAM-1-CLOSURE.md](./docs/post-migrations/PROGRAM-1-CLOSURE.md)

---

## Architecture compliance

| Date | Compliance | Delta | Notes |
|------|------------|-------|-------|
| 2026-05-20 | **52%** | — | CTO audit baseline |
| 2026-05-20 | **57%** | +5 | Phase 1 live: audit log + RLS (M8, M25) |
| 2026-05-20 | **62%** | +5 | Phase 2 Steps 1–2: billing_ledger + market_config (M9 partial) |
| 2026-05-20 | **67%** | +5 | Phase 2 Step 4: trip.completed → ledger live (M9 done) |
| 2026-05-20 | **72%** | +5 | Phase 3 M10A: billing eligibility RPCs live |
| 2026-05-20 | **77%** | +5 | Phase 3 M10B: dispatch billing filter live |
| 2026-06-25 | **82%** | +5 | Phase 3 M10C: accept enforcement + config flag live |

**Target:** 100% V1 spec (Supabase-only prod, billing ledger, waves, audit, strangler complete)

---

## KPIs (CTO dashboard)

| KPI | Score | Notes |
|-----|-------|-------|
| **Architecture compliance** | **82%** | Spec implementation — history below, never delete |
| **Operational readiness** | ~68% | ↑ with Programs 2–4 |
| **Production confidence** | ~85% | Smoke + rollback discipline |
| **Automation** | Manual ~72% · Auto ~28% | Target: 20% / 80% |
| **Technical debt** | **LOW** | Target: VERY LOW → MINIMAL |
| **Driver truth accuracy** | TBD | Target **≥ 98%** at P2 closure |

Architecture = what is built. Operational = how reliably it runs in production.

### Production maturity (by subsystem)

| Subsystem | Maturity | Program |
|-----------|----------|---------|
| Foundation (audit, RLS, market_config) | **100%** | 1 |
| Billing | **100%** | 1 |
| Dispatch | ~65% | 3 |
| Driver Connectivity | ~25% | 2 |
| Backend Consolidation | ~0% | 4 |
| Observability | ~15% | 5 |

---

## Production readiness (summary)

| Gate | Status | Notes |
|------|--------|-------|
| Production health | ~70% | Rider path works; driver Go path fragile |
| V1 spec compliance | **82%** | Phase 3 M10C live (accept enforcement + config flag) |
| TestFlight (NL 4 cities) | 🔴 Not ready | |
| App Store | 🔴 Not ready | |

---

## Mandatory gates (every migration)

No row is **Done** until all four are checked:

| Gate | Meaning |
|------|---------|
| **PRR** ☐ | Production Readiness Review complete (Risk · Blast · Detection · Rollback · Success) |
| **Database** ☐ | Migration in repo; reviewed; staging-ready |
| **Smoke test** ☐ | Automated or scripted test passed |
| **Flutter** ☐ | Rider + Driver compatible (or N/A) |
| **Production** ☐ | Explicit approval + applied to HEYCABY-TAXI |

---

## Definition of Done (DoD)

A migration is **Done** only when **all** apply:

- [ ] Code / SQL implemented
- [ ] Unit or RPC-level test where applicable
- [ ] Smoke test passed (see roadmap phase list)
- [ ] Rider app verified (or N/A documented)
- [ ] Driver app verified (or N/A documented)
- [ ] No regression on existing flows
- [ ] Master Tracker + compliance % updated
- [ ] Rollback path documented and tested
- [ ] Performance acceptable (no new full table scans)
- [ ] Production approval recorded

A **program** is **CLOSED** only when the [Engineering Bible](./docs/ENGINEERING-BIBLE.md) subsystem checklist is fully satisfied (architecture, observability, rollback, smoke, docs, monitoring, metrics).

Status **In Progress** = anything less than the above.

---

## Master migration table

| ID | Feature | Phase | Depends On | Solves (production problem) | Status | Owner | Risk | DB ☐ | Smoke ☐ | Flutter ☐ | Prod ☐ |
|----|---------|-------|------------|-------------------------------|--------|-------|------|------|---------|-----------|--------|
| M8 | Audit log | 1 | — | No unified timeline for support/disputes; can't debug dispatch/billing changes | ✅ Done | AI CTO | Low | ✅ | ✅ | N/A | ✅ |
| M25 | RLS: founding_contract_links + launch_regions | 1 | — | Exposed tables (security advisor critical) | ✅ Done | AI CTO | Low | ✅ | ✅ | N/A | ✅ |
| M9 | Billing ledger + accrual trigger | 2 | M8 | €1/ride accrual + audit | ✅ Done | AI CTO | Med | ✅ | ✅ | N/A | ✅ |
| M10A | Billing eligibility RPCs | 3 | M9 | Derived can_accept + summary + platform_health | ✅ Done | AI CTO | Med | ✅ | ✅ | N/A | ✅ |
| M10B | Dispatch billing filter | 3 | M10A | Skip locked + skip_metrics + v1 | ✅ Closed | AI CTO | Med | ✅ | ✅ | N/A | ✅ |
| M10C | Accept billing enforcement | 3 | M10A, M10B | Hard reject at accept time | ✅ Closed | AI CTO | Med | ✅ | ✅ | N/A | ✅ |
| M11 | Billing settlement RPC | 1 | M10A | Paydown + unlock audit events | Pending (business) | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M4 | Dispatch invites wired | 3 | M8 | Invites table unused; matching never ran in prod | Pending · P3 | AI CTO | High | ☐ | ☐ | ☐ | ☐ |
| M5 | Dispatch waves (4-wave / 90s) | 3 | M4 | Rider wait undefined; unanswered offers | Pending | AI CTO | High | ☐ | ☐ | ☐ | ☐ |
| M6 | Offer expiry cron | 3 | M4 | Stale offers confuse drivers | Pending | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M7 | Cancel-on-accept push | 3 | M4, M5 | Losers still see dead offers | Pending | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M1 | Accept + audit + billing guard | 2–3 | M8, M9, M10C | Accept + billing integration | Partial | AI CTO | Low | ☐ | ☐ | ☐ | ☐ |
| M14 | Presence foundation | 2 · L1 | — | Session/event model (expose) | **M14 RC2 · observe** | AI CTO | Med | ✅ | ✅ | N/A | ✅ |
| M15 | Heartbeat | 2 | M14 | Ghost drivers; 10m idle cron too coarse | Pending · P2 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M16 | Reconnect | 2 | M15 | Tunnel/background/network switch drops presence | Pending · P2 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M17 | Session recovery | 2 | M15 | Duplicate devices; zombie sessions | Pending · P2 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M18 | Stale detection | 2 | M14–M17 | Stale drivers in dispatch pool | Pending · P2 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M12 | Go online / readiness RPC | 4 | M14–M18 | Go 403; dual backend complexity | Pending · P4 | AI CTO | High | ☐ | ☐ | ☐ | ☐ |
| M13 | *(merged into M15)* | 2 | M14 | Heartbeat RPC replaces Go location | — | — | — | — | — | — | — |
| M30 | Ride arrived RPC | 4 | M12 | Lifecycle stuck on Go (was M16) | Pending · P4 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M31 | Trip start RPC | 4 | M30 | Lifecycle stuck on Go (was M17) | Pending · P4 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M32 | Trip complete RPC | 4 | M31, M9 | Lifecycle + fee trigger on Go (was M18) | Pending · P4 | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M19 | Driver cancel RPC | 5 | M12 | Cancel paths fragmented on Go | Pending | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M22 | Boot config RPC | 5 | — | Config split Go vs app_config | Pending | AI CTO | Low | ☐ | ☐ | ☐ | ☐ |
| M23 | Rider nearby supply RPC | 5 | M14 | Nearby drivers via Go | Pending | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M24 | Driver JWT user_type | 5 | — | Go 403 driver role required | Partial | AI CTO | Low | ☐ | ☐ | ☐ | ☐ |
| M2 | Decline ride RPC | 3 | M4 | Decline only on Go | Pending | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M20 | Manual ride + audit | 1 | M8 | Street rides untracked in audit | Partial | AI CTO | Low | ☐ | ☐ | N/A | ☐ |
| M21 | Rider pricing RPC | — | — | — | ✅ Complete | — | Low | ✅ | ✅ | ✅ | ✅ |
| M26 | Idempotency keys | 3–5 | M1, M32 | Retry duplicates on accept/pay | Pending | AI CTO | Med | ☐ | ☐ | ☐ | ☐ |
| M27 | Go decommission | 4 | M12–M23 | Dual backend ops cost + failure modes | Pending · P4 | AI CTO | High | ☐ | ☐ | ☐ | ☐ |
| M28 | Supabase smoke test suite | 5 | M8, M9 | Tests target Go+Redis not Supabase | Pending · P5 | AI CTO | Med | ☐ | ☐ | N/A | ☐ |

**Legend:** Pending · 🟡 In Progress · ✅ Done · Partial · Blocked

---

## Program 1 — ✅ CLOSED (Billing)

Reports: [PROGRAM-1-CLOSURE.md](./docs/post-migrations/PROGRAM-1-CLOSURE.md) · [BILLING-PROGRAM-CLOSURE.md](./docs/post-migrations/BILLING-PROGRAM-CLOSURE.md) · [PHASE-3-M10C-CLOSURE.md](./docs/post-migrations/PHASE-3-M10C-CLOSURE.md)

**Frozen.** No architectural work. Bug fixes · performance · business requirements only.

---

## Current sprint: Program 1.5 — Launch Validation (Shift Certification) 🟡

**Goal:** Prove a real Rotterdam driver can complete a full shift without breaking.  
**Checklist:** [docs/HEYCABY_SHIFT_CERTIFICATION.md](./docs/HEYCABY_SHIFT_CERTIFICATION.md)

| Stage | Status |
|-------|--------|
| Runtime v3 live (Supabase) | ✅ |
| Flutter → `fn_driver_runtime` / `fn_driver_set_status` | ✅ |
| **Shift Certification (Phases 1–10)** | ☐ **In progress — device required** |
| Chaos tests | ☐ After Phases 1–10 pass |
| **Program 2 feature work** | ⛔ **Blocked until Shift Certification pass** |

---

## Next after certification: Program 2 — Driver Connectivity 🟢

**TRB:** [TECHNICAL-REVIEW-BOARD.md](./docs/TECHNICAL-REVIEW-BOARD.md)  
**M14 PRR:** [PRR-M14-RC1.md](./docs/post-migrations/PRR-M14-RC1.md) ✅

### M14 release lifecycle

| Stage | Status |
|-------|--------|
| **M14 RC1** (repo) | ✅ TRB approved |
| **M14 RC2** (smoke on prod) | ✅ Passed 2026-05-19 · **CTO approved** |
| **Production** | ✅ HEYCABY-TAXI · `connectivity_m14_enabled=false` |
| **48h observation** | 🟡 **Active** (ends ~2026-05-21) — observe only, no M15 |
| **M14 GA** | ☐ After clean observation |
| **30d stable** | ☐ After GA |
| **M14 LTS / Freeze** | ☐ After stable window |

**Pipeline (do not skip stages):** RC1 → RC2 → 48h observation → GA → 30d stable → LTS

**M15 Heartbeat:** ⛔ Blocked until M14 GA + freeze. One sentence scope: *keep sessions alive without changing dispatch.*

### Program 2 layers

| Layer | Migrations | Mode |
|-------|------------|------|
| **L1 Foundation** | M14 | Expose ← *observation* |
| **L2 Connectivity** | M15–M17 | Observe → Measure (M15 after M14 LTS) |
| **L3 Enforcement** | M18 | Enforce |
| **Chaos test** | After M17 | Kill app/network/airplane/tunnel/duplicate login — not before |
| **P2 dashboard** | Program 2 active | Sessions · heartbeat · reconnect · drift · truth accuracy (build at M15+) |

Exit criteria: [PROGRAM-2-EXIT-CRITERIA.md](./docs/post-migrations/PROGRAM-2-EXIT-CRITERIA.md)

**Post-migration reports:** [docs/post-migrations/](./docs/post-migrations/)

---

## Phase 1.5 — completed 2026-05-20

Audit enrichment live: `correlation_id`, `actor_type`, `source` on `ride_audit_log` (search by correlation = ride journey).

| Step | Action | Status |
|------|--------|--------|
| 1 | Inspect prod schema via Supabase MCP | ✅ |
| 2 | Migration applied to HEYCABY-TAXI | ✅ `v1_phase1_ride_audit_log_and_rls` |
| 3 | Smoke test (insert → audit → cancel → delete) | ✅ Passed |
| 4 | Production approval | ✅ User approved ("proceed") |

---

## Changelog (execution only)

| Date | ID | Change | Compliance |
|------|-----|--------|------------|
| 2026-05-20 | — | Master Tracker created; planning frozen | 52% |
| 2026-05-20 | M8.5 | Audit correlation + actor columns live | 57% |
| 2026-05-20 | M10B | Dispatch filter + metrics live; smokes passed | 77% |
| 2026-06-25 | M10C | Accept enforcement + flag/grace live; E2E smoke passed | 82% |
| 2026-06-25 | — | Program 1 (Billing) CLOSED; Program 2 approved | 82% |
| 2026-06-25 | — | Program 2 M14 architecture gates frozen | 82% |
| 2026-06-25 | — | PHASE-4-M14-DESIGN published (design-only) | 82% |
| 2026-06-25 | M14 | M14A–E in repo; TRB RC1 approved | 82% |
| 2026-06-25 | — | TRB ratified + PLATFORM-PLAYBOOK + LTS lifecycle | 82% |
| 2026-05-19 | M14 | M14A–D live on HEYCABY-TAXI; smoke passed; `connectivity_m14_enabled=false` | 82% |
| 2026-05-19 | M14 | RC2 CTO approved; 48h observation started; enum cast hotfix in repo | 82% |

---

*Last updated: 2026-05-19*

---

## Document index (frozen)

| Doc | Role |
|-----|------|
| [HEYCABY-MASTER-TRACKER.md](./HEYCABY-MASTER-TRACKER.md) | **Daily status — update here only** |
| [docs/HEYCABY_SHIFT_CERTIFICATION.md](./docs/HEYCABY_SHIFT_CERTIFICATION.md) | **Program 1.5 — full shift validation checklist** |
| [docs/ENGINEERING-BIBLE.md](./docs/ENGINEERING-BIBLE.md) | **Permanent principles + program roadmap** |
| [docs/post-migrations/PROGRAM-1-CLOSURE.md](./docs/post-migrations/PROGRAM-1-CLOSURE.md) | Program 1 executive closure |
| [docs/post-migrations/PROGRAM-2-DRIVER-CONNECTIVITY-DESIGN.md](./docs/post-migrations/PROGRAM-2-DRIVER-CONNECTIVITY-DESIGN.md) | Program 2 frozen design |
| [docs/post-migrations/PROGRAM-2-M14-ARCHITECTURE-GATES.md](./docs/post-migrations/PROGRAM-2-M14-ARCHITECTURE-GATES.md) | M14 architecture gates (frozen) |
| [docs/PLATFORM-PLAYBOOK.md](./docs/PLATFORM-PLAYBOOK.md) | **Platform evolution — company-wide** |
| [docs/TECHNICAL-REVIEW-BOARD.md](./docs/TECHNICAL-REVIEW-BOARD.md) | **TRB — ratified company policy** |
| [docs/ENGINEERING-BIBLE.md](./docs/ENGINEERING-BIBLE.md) | Principles + maturity model |
| [docs/post-migrations/PRR-M14-RC1.md](./docs/post-migrations/PRR-M14-RC1.md) | M14 Production Readiness Review |
| [docs/post-migrations/PHASE-4-M14-POST-MIGRATION-REPORT.md](./docs/post-migrations/PHASE-4-M14-POST-MIGRATION-REPORT.md) | M14 production deploy report |
| [New-Backend-Heycaby.md](./New-Backend-Heycaby.md) | Architecture spec (frozen) |
| [HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md](./HEYCABY-V1-BACKEND-CTO-AUDIT-REPORT.md) | Audit baseline (frozen) |
| [HEYCABY-V1-MIGRATION-ROADMAP.md](./HEYCABY-V1-MIGRATION-ROADMAP.md) | Migration detail (frozen) |

