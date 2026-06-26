# HeyCaby Engineering Bible

**Permanent engineering principles.** Update only when CTO approves a new principle — not per migration.

| Daily status | [HEYCABY-MASTER-TRACKER.md](../HEYCABY-MASTER-TRACKER.md) |
| Architecture spec | [New-Backend-Heycaby.md](../New-Backend-Heycaby.md) |
| Program 2 design | [PROGRAM-2-DRIVER-CONNECTIVITY-DESIGN.md](./post-migrations/PROGRAM-2-DRIVER-CONNECTIVITY-DESIGN.md) |
| M14 architecture gates | [PROGRAM-2-M14-ARCHITECTURE-GATES.md](./post-migrations/PROGRAM-2-M14-ARCHITECTURE-GATES.md) |
| M14 design (approved) | [PHASE-4-M14-DESIGN.md](./post-migrations/PHASE-4-M14-DESIGN.md) |
| Platform strategy | [PLATFORM-PLAYBOOK.md](./PLATFORM-PLAYBOOK.md) |
| Technical Review Board | [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) |

---

## Engineering maturity

> **Engineering maturity is measured not by the number of features shipped, but by the team's ability to change production safely, predictably, and repeatedly.**

That is the defining characteristic of HeyCabby's engineering culture.

> **A production deployment is successful only when users remain unaware that it happened.**

No downtime. No surprises. No support tickets. No regressions. Just a better system.

---

## Company maturity model

| Level | Name | HeyCaby |
|-------|------|---------|
| **1** | Prototype | — |
| **2** | Managed | Past (2026 Q1) |
| **3** | Controlled | Program 1 mid-flight |
| **4** | Governed | **Today** — TRB, PRR, RC, GA, Freeze |
| **5** | Platform | After Programs 2–5 — LTS, KPIs, automation |

Level 5 requires: LTS baselines · Program 2–5 GA · observability program complete · automation KPI ≥80%.

---

## Repeatable methodology (technology-agnostic)

Every program follows:

```
Program
  ↓
Architecture
  ↓
Audit
  ↓
Design
  ↓
Migration
  ↓
Smoke
  ↓
Observation
  ↓
Freeze
  ↓
Closure
```

Program 1 proved the pattern. Program 2 applies it to distributed systems.

---

## Rule lifecycle (every subsystem)

> **Every new business rule must first exist as an observable capability before it becomes an enforced rule.**

```
Design → Expose → Observe → Measure → Enforce → Freeze
```

---

## Truth from events (distributed systems)

> **Truth is derived from events, never assumed from absence.**

> **Events are immutable. State is derived.**

Never infer offline from missing data alone. Append events; project state. Every transition explicit, timed, auditable, config-driven.

---

## Core principles (Program 2 distributed systems)

Together these define how HeyCaby evolves:

1. **Expose → Observe → Measure → Enforce → Freeze**
2. **Truth is derived from events, never assumed from absence**
3. **Events are immutable. State is derived.**
4. **Single writer** — `fn_driver_connectivity_transition` validates legal transitions
5. **Server time authority** — PostgreSQL `now()` only; never trust device clock
6. **Observable before optimized** — every production subsystem must be observable before it is optimized
7. **Measurable success before deploy** — every production deployment must have a measurable definition of success before it begins

> **Every production deployment must have a measurable definition of success before it begins.**

"Deployment succeeded" is not sufficient. See [PRR template](./post-migrations/PRR-TEMPLATE.md).

---

## Release lifecycle (TRB)

```
Design → Repository → RC1 → PRR → RC2 → Production → Observation → **Shift Certification** → GA → LTS → Freeze
```

Governance: [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) · Strategy: [PLATFORM-PLAYBOOK.md](./PLATFORM-PLAYBOOK.md)

**PRR required** before every Level 2+ production deploy (6 questions including Dependencies).

---

## Realtime vs Heartbeat (never conflate)

| Signal | Role | Question |
|--------|------|----------|
| **Realtime** | Transport | Can the server currently communicate with this client? |
| **Heartbeat** | Application health | Is the application still functioning correctly? |

---

## Time authority

Never trust device time. Heartbeat staleness, presence expiry, event ordering, and enforcement use PostgreSQL `timezone('utc', now())` only. Client timestamps are metadata for debugging — not authority.

---

## Four-layer driver model

Never conflate layers in schema, RPCs, or dispatch.

```
Layer 1 — Transport      websocket · network · heartbeat
Layer 2 — Presence       alive · stale · reconnecting
Layer 3 — Operational    available · busy · paused
Layer 4 — Business       billing · documents · vehicle · permissions
```

| Concern | Layer |
|---------|-------|
| Program 1 | Layer 4 (Business) |
| Program 2 | Layers 1–3 (Transport, Presence, Operational) |
| Dispatch | Requires all four layers satisfied |

---

## Platform State vs Business State

| Layer group | Owns |
|-------------|------|
| **Platform State** (Layers 1–3) | Reachability, session, intent |
| **Business State** (Layer 4) | Whether the driver may work |

---

## Single writer (connectivity)

Only **one RPC** — **`fn_driver_connectivity_transition`** — may write authoritative session/presence/operational state. It validates and performs **legal transitions**, it does not arbitrarily set state. All producers emit events; they do not race on direct table updates.

---

## Subsystem completion (Definition of Complete)

> **No subsystem is considered complete until it has architecture, observability, rollback, smoke tests, documentation, monitoring, and production metrics.**

Program 1 satisfies every item. Program 2 additionally requires **7-day observation** and **closure stress test** (100 simulated drivers).

---

## Migration discipline

1. **No single deploy** changes both business rules **and** user-visible behaviour in one step.
2. **Architecture gates frozen** before SQL (Program 2: five gates — see M14 doc).
3. **One endpoint · one migration · one deployment · one observation window**.
4. **Nothing to production** without explicit approval + **PRR** + smoke pass + rollback path.
5. **Never delete compliance history** — the 52 → 82% journey is permanent record.
6. **Config-driven enforcement** — `market_config` flags before hard enforcement.

### Observation windows

| Program type | Minimum window |
|--------------|----------------|
| Business (Billing) | 48 hours |
| Connectivity | **7 days** per program; 48h minimum per migration |

---

## Deploy and rollback

- Prefer **config-driven rollback** over code redeploy.
- Emergency kill switches must work without a new release.
- Hotfixes discovered in smoke → fix in same deploy window, document in post-migration report.

---

## Programs (roadmap order)

| # | Program | Goal | Status |
|---|---------|------|--------|
| 1 | **Foundation + Billing** | 100% | ✅ LTS |
| 2 | **Driver Connectivity** | 100% | 🟢 M14 RC1 |
| 3 | **Dispatch Intelligence** | 100% | Foundation → Observation → Enforcement |
| 4 | **Backend Consolidation** | 100% | Inventory → Replacement → Removal |
| 5 | **Observability** | 100% | Metrics → Dashboards → Alerts |
| 6 | **Production Scale** | 100% | Benchmark → Optimize → Expand |

Program 2 layers: **Foundation (M14)** · **Connectivity (M15–17)** · **Enforcement (M18)**  
TRB: [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) · M14 PRR: [PRR-M14-RC1.md](./post-migrations/PRR-M14-RC1.md)

---

## KPIs (CTO dashboard)

| KPI | Current | Direction |
|-----|---------|-----------|
| Architecture compliance | **82%** | → 100% |
| Operational readiness | ~68% | ↑ with P2–P4 |
| Production confidence | ~85% | ↑ |
| Automation | Manual ~72% · Auto ~28% | → 20% / 80% |
| Technical debt | **LOW** | → MINIMAL |
| **Driver truth accuracy** | TBD (P2) | **≥ 98%** at P2 closure |

### Production maturity (by subsystem)

| Subsystem | Maturity |
|-----------|----------|
| Foundation | **100%** |
| Billing | **100%** |
| Driver Connectivity | ~10% (architecture frozen) |
| Dispatch | ~65% |
| Backend Consolidation | ~0% |
| Observability | ~15% |

---

## What closed programs accept

**Program 1 (Billing)** — bug fixes · performance · business requirements only. No architectural reopen.

---

*CTO architecture review 2026-06-25. Program 2 gates frozen.*
