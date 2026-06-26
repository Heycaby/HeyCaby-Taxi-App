# HeyCaby Technical Review Board (TRB)

**Status:** ✅ **Ratified — company policy** (not project-only)  
**Applies to:** HeyCaby, TalkLingo, Hafrika, and future products

**Role:** Approve production evolution — not architecture design.  
**Chairman lens:** When architecture is frozen, **execution discipline** is the bottleneck.

| Ecosystem | Link |
|-----------|------|
| Platform strategy | [PLATFORM-PLAYBOOK.md](./PLATFORM-PLAYBOOK.md) |
| Engineering principles | [ENGINEERING-BIBLE.md](./ENGINEERING-BIBLE.md) |
| Daily status | [HEYCABY-MASTER-TRACKER.md](../HEYCABY-MASTER-TRACKER.md) |

This document describes **how engineering decisions are approved** — not what the system does.

---

## Mandate

Every production deployment is judged against the **engineering process**, not merely whether code compiles or SQL applies cleanly.

The TRB ensures:

- Risk is explicit before deploy
- Rollback is tested before deploy
- Success is measurable before deploy
- Observation happens after deploy
- Frozen / LTS baselines stay stable

---

## Release lifecycle (official model)

```
Architecture
  ↓
Design
  ↓
Repository
  ↓
RC1
  ↓
PRR
  ↓
RC2
  ↓
Production
  ↓
Observation
  ↓
GA
  ↓
LTS          ← Long-Term Stable baseline (~30 days post-GA)
  ↓
Freeze
```

### Stage definitions

| Stage | Meaning | Gate |
|-------|---------|------|
| **RC1** | Migration + smoke in repo; design approved | TRB repo review |
| **PRR** | Production Readiness Review complete | TRB (6 questions) |
| **RC2** | Smokes pass on target env (ROLLBACK on prod where applicable) | Engineering |
| **Production** | Applied to production | Explicit approval + PRR |
| **GA** | Observation window complete; success metrics met | TRB sign-off |
| **LTS** | ~30 days post-GA: no regressions, no hotfixes, stable metrics | TRB Chairman |
| **Freeze** | Official baseline; incident-only changes | Executive closure |

**Naming:** `M14 RC1` → `M14 RC2` → `M14 GA` → `M14 LTS` → `M14 Freeze`

**LTS purpose:** Future migrations and programs compare against LTS — the trusted baseline.

Example: `M10C GA → 30 days stable → M10C LTS`

---

## Approval levels

Scales governance as the team grows.

### Level 1 — Minor

**Examples:** indexes, views (read-only), documentation, comments  
**Approval:** standard peer review — no TRB meeting required

### Level 2 — Behavior

**Examples:** RPCs, business rules, billing logic, presence transitions, config that changes behaviour  
**Approval:** **CTO** (or delegate)

### Level 3 — Architecture

**Examples:** new subsystem, backend consolidation, dispatch engine, authentication model  
**Approval:** **Technical Review Board**

| Level | TRB meeting | PRR | RC lifecycle |
|-------|-------------|-----|--------------|
| 1 | Optional | Optional | Simplified |
| 2 | If PRR triggered | Required for prod | Full RC recommended |
| 3 | Required | Required | Full RC mandatory |

---

## Production Readiness Review (PRR)

**Mandatory for every Level 2+ production deployment.**

| # | Question | Must document |
|---|----------|---------------|
| 1 | **Risk** | What could break? |
| 2 | **Blast radius** | Which users / subsystems affected? |
| 3 | **Detection** | How will we know if it failed? |
| 4 | **Rollback** | How quickly can we recover? |
| 5 | **Success** | What metrics prove it worked? |
| 6 | **Dependencies** | What must already exist? (order safety) |

**Template:** [PRR-TEMPLATE.md](./post-migrations/PRR-TEMPLATE.md)  
**Example:** [PRR-M14-RC1.md](./post-migrations/PRR-M14-RC1.md)

> **Every production deployment must have a measurable definition of success before it begins.**

---

## Review gates

| Gate | Owner | Blocks |
|------|-------|--------|
| Architecture | CTO / Architect | Design |
| Design | CTO | Repository |
| RC1 | TRB | PRR / RC2 |
| PRR | TRB | Production |
| RC2 | Engineering | Production |
| Production | CTO + TRB | Observation |
| GA | TRB | LTS |
| LTS | TRB Chairman | Freeze |
| Freeze | Executive | — |

---

## Rollback standards

1. Config rollback first (`market_config`, feature flags)
2. SQL rollback script in repo — tested in ROLLBACK smoke
3. PRR documents time-to-recover
4. No production deploy without rollback path

---

## Observation windows

| Program type | Minimum |
|--------------|---------|
| Business (Billing) | 48h per migration |
| Connectivity | 48h per migration · 7 days program |
| Dispatch / Consolidation | 48h+ (TRB may extend) |
| **LTS qualification** | **~30 days post-GA** stable |

---

## Freeze vs LTS

| State | Meaning |
|-------|---------|
| **GA** | Metrics met; feature live; observation complete |
| **LTS** | 30+ days stable; no regressions; official comparison baseline |
| **Freeze** | No enhancements; critical fixes only; program closed |

Program 1 Billing: ✅ LTS baseline (M10A–M10C frozen)  
Program 2 M14: RC1

---

## Company program status (HeyCaby)

| Program | Status |
|---------|--------|
| Foundation | ✅ Complete |
| Billing | ✅ Complete · LTS |
| Driver Connectivity | 🟡 M14 RC1 |
| Dispatch Intelligence | ⏳ Planned |
| Backend Consolidation | ⏳ Planned |
| Observability | ⏳ Planned |
| Production Scale | ⏳ Planned |

---

## TRB decision log

| Date | Decision |
|------|----------|
| 2026-06-25 | TRB charter established |
| 2026-06-25 | RC lifecycle + PRR mandatory |
| 2026-06-25 | M14 RC1 approved |
| 2026-06-25 | **TRB ratified as company policy** |
| 2026-06-25 | LTS stage adopted |
| 2026-06-25 | Three approval levels defined |
| 2026-06-25 | PLATFORM-PLAYBOOK ratified |

---

## Document index

| Document | Purpose |
|----------|---------|
| [PLATFORM-PLAYBOOK.md](./PLATFORM-PLAYBOOK.md) | How platform evolves |
| [TECHNICAL-REVIEW-BOARD.md](./TECHNICAL-REVIEW-BOARD.md) | This handbook |
| [ENGINEERING-BIBLE.md](./ENGINEERING-BIBLE.md) | Principles |
| [PRR-TEMPLATE.md](./post-migrations/PRR-TEMPLATE.md) | Blank PRR |
| [PRR-M14-RC1.md](./post-migrations/PRR-M14-RC1.md) | M14 PRR |

---

*Execution discipline scales every product — not architecture debates alone.*
