# Platform Playbook

**Scope:** Company-wide — HeyCaby, TalkLingo, Hafrika, and future products.  
**Sits above:** [ENGINEERING-BIBLE.md](./ENGINEERING-BIBLE.md) (how engineers work) · [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) (how changes are approved)

This document defines **how the platform evolves over years** — not day-to-day migration detail.

| Operational detail | Link |
|--------------------|------|
| Daily status | [HEYCABY-MASTER-TRACKER.md](../HEYCABY-MASTER-TRACKER.md) |
| Architecture spec (HeyCaby) | [New-Backend-Heycaby.md](../New-Backend-Heycaby.md) |

---

## Purpose

Answer strategic questions before tactical ones:

- How do we start a new subsystem?
- When do we create a new Program?
- When is a migration required vs a configuration change?
- What qualifies as a breaking change?
- When do we add a new service vs extend what exists?
- What metrics justify new infrastructure (Go, Redis, queues)?

---

## Company program roadmap (HeyCaby)

| Program | Delivers | Status |
|---------|----------|--------|
| **Foundation** | Audit log, RLS, market_config, migration discipline | ✅ Complete |
| **Billing** | Ledger, eligibility, dispatch filter, accept enforcement | ✅ Complete · LTS |
| **Driver Connectivity** | Sessions, events, heartbeat, presence truth | 🟡 M14 RC1 |
| **Operational Readiness (P3)** | 12-hour shift: GPS, recovery, comms, nav, resilience | 🚧 **Active** — see [HEYCABY-LAUNCH-ROADMAP.md](./HEYCABY-LAUNCH-ROADMAP.md) |
| **Premium Driver UI (P4)** | Redesign finished flows only | ⏳ Blocked on P3 |
| **Rider Experience (P5)** | Rider parity + sync | ⏳ After P4 |
| **Launch (P6)** | Certification + App Store | ⏳ Final gate |
| **Dispatch Intelligence** | Waves, expiry, retry, marketplace dispatch | ⏳ Planned |
| **Backend Consolidation** | Go strangler → Supabase-native | ⏳ Planned |
| **Observability** | Metrics, dashboards, alerts, tracing | ⏳ Planned |
| **Production Scale** | Benchmark, optimize, expand | ⏳ Planned |

**Note:** Program 1 delivered two durable outcomes — **Foundation** and **Billing** — preserved separately in history.

**Operational docs:** [RIDE_STATE_MACHINE.md](../apps/driver/docs/RIDE_STATE_MACHINE.md) · [OPERATIONS-PLAYBOOK.md](./OPERATIONS-PLAYBOOK.md)

---

## When to create a new Program

Create a **Program** (not just a migration) when **all** apply:

1. New subsystem with its own lifecycle (Expose → Enforce)
2. Multiple migrations over weeks/months
3. Distinct success metrics and observation window
4. Cross-cutting impact on dispatch, riders, drivers, or ops
5. TRB Level 3 (Architecture) approval required

**Do not create a Program for:** single index, view, bugfix, config tweak, or doc-only change.

---

## When to start a new subsystem

Follow this sequence:

```
1. Problem statement     — What production pain? Who feels it?
2. Architecture gates    — Frozen before SQL (see Program 2 M14 gates)
3. Design doc            — Events, state, RPCs, boundaries
4. Program charter       — Layers: Foundation → Observation → Enforcement
5. RC lifecycle          — TRB governance
6. Executive closure     — LTS baseline
```

Every subsystem must be **observable before optimized** (Engineering Bible).

---

## Migration vs configuration change

| Change type | Use | Approval | Example |
|-------------|-----|----------|---------|
| **Configuration** | Business rule toggle, threshold, market rollout | Level 1–2 | `billing_enforcement=false`, `connectivity_m14_enabled` |
| **Migration** | Schema, RPC contract, state machine, new table | Level 2–3 + PRR | `driver_sessions`, `fn_driver_connectivity_transition` |
| **Program** | New subsystem | Level 3 + TRB | Driver Connectivity, Dispatch Intelligence |

**Default:** If you can solve it with `market_config` and no schema change, prefer configuration.

**Rule:** Configuration changes still need PRR when they alter user-visible behaviour in production.

---

## Breaking change definition

A change is **breaking** if any apply:

| Category | Breaking |
|----------|----------|
| RPC response shape | Removed or renamed required fields |
| RPC behaviour | Previously valid calls now fail |
| Database | NOT NULL on existing column without default |
| Client contract | Flutter/Go must deploy in lockstep |
| Dispatch / billing | Eligibility rules change without flag |

**Non-breaking (additive):** New optional JSON keys, new tables unused until flag on, new RPCs, new views.

Breaking changes require: design doc · PRR · coordinated client release · extended observation.

---

## Extend vs new service

**Extend existing stack (Supabase-first)** when:

- Logic fits RPC + Postgres + RLS
- Event volume < thousands/sec per entity
- Strong consistency required (billing, dispatch, sessions)
- Team can own one operational surface

**Introduce new service (Go, Edge, queue)** only when PRR proves:

| Justification | Metric / evidence |
|---------------|-------------------|
| Latency | p99 RPC > target under load; profiled bottleneck |
| Throughput | Postgres connection or CPU saturated |
| Protocol | WebSocket fan-out, long-running jobs, non-HTTP clients |
| Isolation | Blast radius of monolith deploy unacceptable |
| Strangler | Replacing Go endpoint one-at-a-time (Program 4) |

**Default:** Extend Supabase. New infrastructure requires TRB Level 3 + written cost/ops ownership.

**Current HeyCaby stance:** Go remains strangler-only until Backend Consolidation retires endpoints with observation per endpoint.

---

## Infrastructure decision matrix

| Need | First choice | Escalate when |
|------|--------------|---------------|
| Config per market | `market_config` | — |
| Async work | Postgres cron + `pg_net` / Edge Function | Queue depth or retry complexity |
| Cache | Materialized views / read replicas | Proven read hot spot |
| Realtime | Supabase Realtime | Custom fan-out at scale (measure first) |
| Search | Postgres indexes + RPC | Full-text at scale (Program 5 metrics) |
| Sessions / state | Postgres events + projection | — (Program 2 model) |
| Redis | **Not default** | TRB approves with load evidence |

---

## Release lifecycle (company standard)

See [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) for full detail.

```
Architecture → Design → Repository → RC1 → PRR → RC2 → Production
  → Observation → GA → LTS → Freeze
```

**LTS (Long-Term Stable):** ~30 days after GA with no regressions, no hotfixes, stable metrics — official baseline future migrations compare against.

Example: `M10C GA → 30 days → M10C LTS`

---

## Approval levels (summary)

| Level | Examples | Approval |
|-------|----------|----------|
| **1 — Minor** | Indexes, views, docs | Standard review |
| **2 — Behavior** | RPCs, business rules, billing, presence | CTO |
| **3 — Architecture** | New subsystem, consolidation, dispatch engine, auth | TRB |

Full matrix: TRB handbook.

---

## Engineering maturity levels (company)

| Level | Name | Characteristics |
|-------|------|-----------------|
| **1** | Prototype | No governance |
| **2** | Managed | Architecture, docs |
| **3** | Controlled | Smoke, rollback, observation |
| **4** | Governed | TRB, PRR, RC, GA, Freeze |
| **5** | Platform | LTS, KPIs, automation, full observability |

**HeyCaby today:** **Level 4** — Level 5 after Programs 2–5 complete.

---

## Five-year evolution principles

1. **Supabase-native first** — strangler Go, don't fork backends
2. **Events immutable, state derived** — every subsystem
3. **One writer per truth domain** — billing ledger, connectivity sessions, dispatch state
4. **Config before code** — flags and markets before enforcement
5. **Programs over hero migrations** — Foundation → Observation → Enforcement
6. **Invisible deployments** — users unaware production changed
7. **LTS baselines** — compare forward, never rewrite history

---

## Document hierarchy

```
PLATFORM-PLAYBOOK.md          ← how the platform evolves (this doc)
├── ENGINEERING-BIBLE.md      ← principles + maturity
├── TECHNICAL-REVIEW-BOARD.md ← approval + RC + PRR + LTS
├── HEYCABY-MASTER-TRACKER.md ← daily execution status
└── post-migrations/          ← design, PRR, closure per migration
```

---

## TRB ratification

| Policy | Status |
|--------|--------|
| TECHNICAL-REVIEW-BOARD.md | ✅ Ratified — company policy |
| PRR mandatory | ✅ |
| RC lifecycle | ✅ Official release model |
| LTS after GA | ✅ Adopted |
| This Platform Playbook | ✅ Ratified 2026-06-25 |

---

*Reusable across products — not HeyCaby-specific implementation detail.*
