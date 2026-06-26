# Program 2 — Driver Connectivity

**Status:** 🟢 **Architecture gates frozen — M14 SQL design next (no prod deploy)**  
**Date:** 2026-06-25  
**Prerequisite:** Program 1 (Billing) ✅ CLOSED

| Governance | Link |
|------------|------|
| Engineering Bible | [ENGINEERING-BIBLE.md](../ENGINEERING-BIBLE.md) |
| **M14 architecture gates (frozen)** | [PROGRAM-2-M14-ARCHITECTURE-GATES.md](./PROGRAM-2-M14-ARCHITECTURE-GATES.md) |
| Daily tracker | [HEYCABY-MASTER-TRACKER.md](../../HEYCABY-MASTER-TRACKER.md) |
| Platform health (existing) | `fn_driver_platform_health()` — extended incrementally |

---

## Mission

Build a highly reliable driver connectivity layer that guarantees the platform always knows the **true operational state** of every driver.

Program 2 is **not** about adding features. It is about making driver presence **accurate, resilient, observable, and production-safe**.

When Program 2 is complete, the dispatch engine should always know whether a driver is **genuinely available** to receive rides.

> Program 1 ensured the platform made the **right decisions**.  
> Program 2 ensures the platform continues making the right decisions when phones lose signal, networks fluctuate, or drivers move through real-world conditions.

Program 2 does not exist to make dispatch faster. It exists to make dispatch **trustworthy**.

---

## Engineering philosophy

Same operating model as Program 1. Every capability passes through:

```
Design
  ↓
Expose
  ↓
Observe
  ↓
Measure
  ↓
Enforce
  ↓
Freeze
```

**Rules:**

- No migration may combine multiple behavioural changes.
- Each migration requires: architecture review · smoke tests · rollback · production monitoring · post-migration report · observation window · executive closure.

---

## Objective

Resilient against:

| Failure mode | Examples |
|--------------|----------|
| Temporary network loss | Tunnel, elevator, dead zone |
| Mobile backgrounding | iOS/Android suspend |
| GPS interruption | Indoor, multi-path |
| Poor signal | 3G/EDGE, congested LTE |
| Device reconnects | WiFi ↔ cellular switch |
| Duplicate sessions | Same driver, two devices |
| Zombie sessions | Force-close without logout |
| Stale locations | Ghost drivers on map |

**Constraint:** No negative impact on riders during rollout (expose/observe before enforce).

---

## Platform State vs Business State

| Layer group | Question |
|-------------|----------|
| **Platform State** (Layers 1–3) | What is the truth about connectivity and intent? |
| **Business State** (Layer 4) | Is the driver allowed to work? |

**Authoritative architecture (frozen):** [PROGRAM-2-M14-ARCHITECTURE-GATES.md](./PROGRAM-2-M14-ARCHITECTURE-GATES.md)

---

## Driver state model (four layers — frozen)

```
Layer 1 — Transport      websocket · network · heartbeat
Layer 2 — Presence       alive · stale · reconnecting
Layer 3 — Operational    available · busy · paused
Layer 4 — Business       billing · documents · vehicle · permissions
```

- **Session model:** `driver_sessions` — not `drivers` extension
- **Presence:** Realtime + Heartbeat (different purposes)
- **State machine:** Explicit enums; illegal transitions fail
- **Single writer:** `fn_driver_connectivity_transition`
- **Device identity:** New login supersedes old session (M17)
- **Principle:** Truth from events, never from absence

**Today (pre-P2):** `drivers.status` conflates layers. M14 exposes gap; legacy mirror deprecated after observation.

---

## Program structure (three layers)

| Layer | Scope | Migrations | Lifecycle phase |
|-------|-------|------------|-----------------|
| **L1 Foundation** | Sessions, events, transition RPC, observability | M14 | Expose |
| **L2 Connectivity** | Heartbeat, reconnect, session recovery, stale detection | M15–M17 | Observe → Measure |
| **L3 Enforcement** | Dispatch filter, presence, availability | M18 | Enforce |

---

| ID | Name | Mode | Dispatch impact |
|----|------|------|-----------------|
| **M14** | Presence Foundation | Expose | None |
| **M15** | Heartbeat | Expose → Observe | None |
| **M16** | Reconnect | Observe → Measure | None |
| **M17** | Session Recovery | Measure | None |
| **M18** | Stale Detection | Measure → Enforce | Soft filter after observation |

**Note:** Ride-lifecycle RPCs formerly listed as M16–M18 in the V1 roadmap are renumbered **M30–M32** under Program 4 (Backend Consolidation) to avoid ID collision.

**M13** (Heartbeat RPC / Go location replacement) merges into **M15** deliverables.

---

### M14 — Presence Foundation

**Purpose:** Introduce the concept of driver presence.

**Deliverables:**

- `driver_sessions` table (see architecture gates)
- Explicit state machine enums (transport, presence, operational)
- `fn_driver_connectivity_transition` — single writer (expose path only in M14)
- Presence RPCs (read) + `connectivity.*` audit events
- Presence metrics in RPC responses (no enforcement)

**Explicitly out of scope:**

- Dispatch filter changes
- Go-online behaviour changes
- Billing or business logic

**Success:** Ops can query "who is present vs who is marked available" and see the gap.

---

### M15 — Heartbeat

**Purpose:** Determine whether a driver's session is alive.

**Responsibilities:**

- Timestamp updates (`last_heartbeat_at`)
- Connection freshness scoring
- Session health signal for `fn_driver_platform_health`

**Constraints:**

- Lightweight — no billing, dispatch, or business logic in heartbeat path
- Configurable interval via `market_config` (observe before enforce)
- Replaces/supersedes coarse `mark_idle_drivers_offline` cron where proven

**Deliverables:**

- `fn_driver_heartbeat()` RPC (includes location passthrough — absorbs M13)
- Heartbeat audit events (`connectivity.heartbeat_received`)
- Flutter integration plan (driver app sends on interval + foreground resume)

---

### M16 — Reconnect

**Purpose:** Recover gracefully from temporary connection loss.

**Scenarios:**

- Tunnel / elevator
- Mobile data interruption
- App background → foreground
- Network switch (WiFi ↔ cellular)

**Goal:** Restore presence without requiring manual go-online when session is still valid.

**Deliverables:**

- Reconnect RPC or heartbeat variant with session token
- `connectivity.reconnected` audit events
- Metrics: reconnect latency, reconnect success rate

**Mode:** Observe → Measure (no auto-offline enforcement yet).

---

### M17 — Session Recovery

**Purpose:** Ensure one valid operational session per driver.

**Handles:**

- Duplicate devices
- App restart
- Force close
- Token refresh
- Device reboot

**Deliverables:**

- Authoritative session selection logic
- Session supersede / invalidate events
- `connectivity.session_*` audit namespace
- Multi-device safety rules (new login supersedes stale, with audit)

---

### M18 — Stale Detection

**Purpose:** Automatically detect inactive sessions.

**Responsibilities (after observation window proves thresholds):**

- Remove stale drivers from dispatch candidate pool
- Expire stale presence
- Clear stale availability (config-driven)
- Preserve full audit history

**Enforcement gate:** Requires M14–M17 metrics showing false-offline rate acceptable. Config flag: `connectivity_stale_enforcement` per market (same pattern as `billing_enforcement`).

**Deliverables:**

- Stale detection cron or trigger
- `skip_metrics.stale` in dispatch (parallel to M10B billing skip)
- Rollback via `market_config` without redeploy

---

## Platform health (single readiness endpoint)

`fn_driver_platform_health()` is the **single readiness object** for Flutter.

**Today (Program 1):** billing · driver verification · dispatch_eligible (partial)

**Program 2 additions (incremental per migration):**

```json
{
  "allowed": false,
  "billing": { "...": "..." },
  "driver": { "...": "..." },
  "connectivity": {
    "connection": "connected | disconnected",
    "presence": "present | stale",
    "last_heartbeat_at": "...",
    "session_id": "...",
    "reconnect_pending": false
  },
  "availability": {
    "status": "available | busy | offline"
  },
  "dispatch": {
    "eligible": false,
    "reasons": ["billing_locked", "stale_presence"]
  }
}
```

Flutter retrieves **one object** — no scatter of endpoints.

---

## Operational KPIs

Track continuously during each observation window.

### Connectivity

| Metric | Source |
|--------|--------|
| **Driver truth accuracy** | Platform vs client state ≥ 98% at closure |
| Heartbeat success rate | RPC logs / audit |
| Average reconnect time | `connectivity.reconnected` events |
| Session recovery rate | M17 audit |
| False offline rate | Present drivers marked offline incorrectly |

### Dispatch

| Metric | Source |
|--------|--------|
| Eligible drivers | `fn_driver_platform_health` aggregate |
| Connected vs present vs available | Presence RPC / view |
| Average dispatch delay | Existing M10B `dispatch_duration_ms` |

### Reliability

| Metric | Source |
|--------|--------|
| Stale session count | M18 detection |
| Duplicate session count | M17 audit |
| Unexpected disconnects | Realtime + audit |

### Engineering

| Metric | Source |
|--------|--------|
| RPC latency (heartbeat) | Supabase logs |
| Realtime latency | Client telemetry |
| Trigger / cron failures | Postgres logs |

---

## Success criteria (program closure)

Program 2 is **CLOSED** only when **all** apply:

- [ ] Driver presence accurately reflects real connectivity
- [ ] Heartbeats recover from temporary network failures
- [ ] Duplicate sessions safely handled (one authoritative session)
- [ ] Stale sessions automatically expire (with config rollback)
- [ ] Dispatch receives reliable availability information
- [ ] Observability dashboards or query pack exist
- [ ] Rollback procedures tested for every migration
- [ ] Smoke tests cover every migration (M14–M18)
- [ ] Production metrics healthy through **7-day** observation windows (48h min per migration)
- [ ] **Stress test passed** (100 simulated drivers — see architecture gates)
- [ ] Executive closure report published

Plus [Engineering Bible](../ENGINEERING-BIBLE.md) subsystem checklist.

---

## Rollout sequence

```
M14 (expose presence)
  → observe gap between presence and availability
M15 (heartbeat)
  → observe heartbeat coverage and interval
M16 (reconnect)
  → measure reconnect success without enforce
M17 (session recovery)
  → measure duplicate session rate
M18 (stale detection)
  → enforce dispatch filter after flag + observation
  → freeze
```

**No dispatch enforcement until M18** (and only with `connectivity_stale_enforcement` config).

---

## Dependencies

| Depends on | Reason |
|------------|--------|
| Program 1 (Billing) | `fn_driver_platform_health` billing section live |
| M8 audit log | `connectivity.*` events use same append-only pattern |
| `market_config` | Thresholds and enforcement flags per market |

| Blocks | Reason |
|--------|--------|
| Program 3 (Dispatch Intelligence) | Waves need trustworthy candidate pool |
| Program 4 M12 (Go online) | Readiness RPC needs presence layer |
| Program 4 M23 (Nearby supply) | Supply RPC needs fresh presence + location |

---

## Before M14 SQL

Architecture gates ✅ **frozen** — [PROGRAM-2-M14-ARCHITECTURE-GATES.md](./PROGRAM-2-M14-ARCHITECTURE-GATES.md)

**M14 design (pending approval):** [PHASE-4-M14-DESIGN.md](./PHASE-4-M14-DESIGN.md) — events, transition table, DDL proposal, sequences, smoke, rollback, observation. **No migration until CTO sign-off.**

---

## Document index

| Doc | When |
|-----|------|
| This file | Program definition (frozen) |
| `PHASE-4-M14-DESIGN.md` | Before M14 SQL (TBD) |
| Post-migration reports | After each migration live |
| `PROGRAM-2-CLOSURE.md` | When success criteria met |

---

*CTO formal definition 2026-06-25. Architecture gates frozen 2026-06-25. No prod M14 until PHASE-4-M14-DESIGN approved.*
