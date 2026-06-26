# Program 2 — M14 Architecture Gates (FROZEN)

**Status:** ✅ **Architecture frozen — M14 SQL may proceed after sign-off**  
**Date:** 2026-06-25  
**CTO decision:** Do not write M14 migration until architecture gates + `PHASE-4-M14-DESIGN.md` are approved.

| Parent | [PROGRAM-2-DRIVER-CONNECTIVITY-DESIGN.md](./PROGRAM-2-DRIVER-CONNECTIVITY-DESIGN.md) |
| M14 design | [PHASE-4-M14-DESIGN.md](./PHASE-4-M14-DESIGN.md) |
| Governance | [ENGINEERING-BIBLE.md](../ENGINEERING-BIBLE.md) |

---

## Why Program 2 is different

| Program 1 | Program 2 |
|-----------|-------------|
| Business correctness | Distributed systems |
| *"Should this driver be allowed?"* | *"What is the truth about this driver right now?"* |
| Derived state from ledger | Derived state from events + timeouts |
| 48h observation window | **7-day** observation window |

Program 2 is fundamentally harder. Architecture must be frozen before any SQL.

---

## Four-layer driver model (formal)

Dispatch evaluates drivers only when **all four layers** are satisfied.

```
Layer 1 — Transport     websocket · network · heartbeat
        ↓
Layer 2 — Presence      alive · stale · reconnecting
        ↓
Layer 3 — Operational   available · busy · paused
        ↓
Layer 4 — Business      billing · documents · vehicle · permissions
```

| Layer | Program owner | Never conflated with |
|-------|---------------|----------------------|
| Transport + Presence | Program 2 | Business eligibility |
| Operational | Program 2 (M14–M18) + dispatch | Transport disconnect |
| Business | Program 1 (billing) + compliance | Online/offline intent |

---

## Permanent principles (Program 2)

> **Truth is derived from events, never assumed from absence.**

> **Events are immutable. State is derived.**

Wrong:

```
No heartbeat → Offline
```

Right:

```
No heartbeat
  → Timeout exceeded (config)
  → Presence: stale (event + audit)
  → Dispatch: removed from pool (enforce, after observation)
  → Operational: offline (explicit transition)
```

Every transition is explicit, auditable, and reversible via config where possible.

---

# Gate 1 — Session Model ✅ FROZEN

**Decision:** Do **not** extend `drivers` for session lifecycle. Create **`driver_sessions`**.

**Rationale:** A driver is permanent. A session is temporary. Different entities.

```
drivers                          driver_sessions
──────────────                   ────────────────────────
id (permanent)                   id (session_id)
name, vehicle, billing, docs     driver_id → drivers.id
                                 device_id (stable per install)
                                 connected_at
                                 last_heartbeat_at
                                 last_realtime_at
                                 transport_state
                                 presence_state
                                 operational_state (intent mirror)
                                 ended_at (null = open session)
                                 end_reason
                                 app_version
                                 platform (ios | android)
                                 push_token (nullable)
                                 is_authoritative (one true per driver)
```

**Invariants:**

- One driver → many historical sessions
- **One authoritative active session** per driver at any time
- `drivers` row holds identity and business fields only — not live connectivity

**M14 scope:** Table + indexes + RLS + read RPCs + audit append. No dispatch enforcement.

---

# Gate 2 — Presence ✅ FROZEN

**Decision:** Use **both** Realtime and Heartbeat — different purposes.

| Signal | Role | Question |
|--------|------|----------|
| **Realtime** | **Transport** | Can the server currently communicate with this client? |
| **Heartbeat** | **Application health** | Is the application still functioning correctly? |

Those must **never** be treated as the same signal.

**Why both:**

```
Realtime disconnected
  → Reconnect in 2s
  → Driver should NOT immediately leave dispatch pool
```

Realtime alone is too volatile. Heartbeat provides stability and survives brief websocket blips.

**Storage:**

- `last_realtime_at` — updated from Realtime presence channel (client or edge relay)
- `last_heartbeat_at` — updated only via single-writer RPC (Gate 4)

**Stale thresholds:** Separate config keys in `market_config`:

- `connectivity_realtime_stale_seconds`
- `connectivity_heartbeat_stale_seconds`

Observe before enforce (M14–M17). Enforce in M18.

---

# Gate 3 — State Machine ✅ FROZEN

**Decision:** **Forbid** ad-hoc string statuses (`online`, `offline`, `busy` as free text).

Use **explicit enums** and **legal transitions only**. Illegal transitions fail with audit.

### Transport state

```
disconnected ↔ connected
```

### Presence state

```
unknown → present → stale → reconnecting → present
                    ↓
                  ended
```

### Operational state (driver intent)

```
offline → available → busy → available → offline
              ↓
           paused
```

**Paused:** Driver online but not accepting new dispatch (distinct from busy-on-ride).

### Transition rules

- **Every state transition documented** in the transition table — the table is the contract for Flutter, Supabase, and Go replacements. See [PHASE-4-M14-DESIGN.md §4](./PHASE-4-M14-DESIGN.md#4-state-transition-table-contract).
- Every state change writes `connectivity.state_transition` to audit log with `{ from, to, layer, reason, session_id }`
- RPC validates `(from_state, event_type)` → `to_state` — reject illegal jumps
- Legacy `drivers.status` is **read-only mirror** during transition; deprecated after observation proves parity

**Implementation:** Postgres enums or CHECK + transition function — decided in M14 SQL design doc, not here.

---

# Gate 4 — Single Writer ✅ FROZEN

**Decision:** Only **one RPC** may write authoritative session/presence/operational state.

**Frozen RPC name:** `fn_driver_connectivity_transition(p_event jsonb)`

The RPC does not "set" state — it **validates and performs a legal transition**.

Even if these produce *signals*:

| Source | Role |
|--------|------|
| Flutter app | Heartbeat, explicit go-online/offline, reconnect |
| Supabase Realtime | Transport signal (may call writer or queue event) |
| Go (strangler) | Forwards to writer during coexistence — never writes session table directly |
| Admin | Support override via same writer with `actor_type: admin` audit |
| Cron (M18) | Stale detection emits events into writer — never raw UPDATE |

**Anti-pattern (forbidden):** Flutter UPDATE on `drivers.status` + Go POST + cron UPDATE racing each other.

**Read path:** Multiple readers (`fn_driver_platform_health`, dispatch seed, admin views).

---

# Gate 5 — Failure Strategy ✅ FROZEN

Design for failure first. Every scenario has defined behaviour.

| Scenario | Transport | Presence | Operational | Dispatch |
|----------|-----------|----------|-------------|----------|
| Phone dies / battery removed | disconnected | → stale (heartbeat timeout) | → offline (after grace) | removed after M18 enforce |
| Internet gone | disconnected | reconnecting → stale if timeout | unchanged until stale chain | not offered if stale |
| SIM / network switch | disconnected briefly | reconnecting | unchanged | brief gap tolerated |
| App backgrounded (iOS) | may disconnect | heartbeat may slow (config) | unchanged if within thresholds | observe only in M15–M17 |
| Force-kill by OS | disconnected | stale | offline | removed |
| Tunnel / elevator | disconnected | reconnecting | unchanged | no instant removal |
| Roaming / VPN | connected (degraded) | present if heartbeat OK | unchanged | observe latency KPI |
| Clock drift | — | reject heartbeat if skew > N sec | — | audit + ignore |
| Duplicate device login | — | M17: supersede old session | old → offline | old session ineligible |

**Grace periods:** All timeouts in `market_config` — tunable without deploy.

**No silent assumptions:** Absence of signal never immediately equals offline (see truth-from-events principle).

### Recovery (equal priority to failure)

| Failure | Recovery |
|---------|----------|
| Tunnel | Heartbeat resumes + transport.connected |
| App killed | New `session.start` on next launch |
| Duplicate login | Old session superseded; new authoritative |
| Device reboot | Fresh session |
| Push token rotated | Update session metadata via transition |
| Clock drift | Ignore client time; trust server `now()` only |

---

# Gate 6 — Time Authority ✅ FROZEN

**Decision:** Never trust device time. Only trust PostgreSQL `timezone('utc', now())`.

| Use server time for | Never use client time for |
|---------------------|---------------------------|
| Heartbeat staleness | Expiry decisions |
| Presence timeouts | Transition ordering |
| Event `occurred_at` | Enforcement triggers |
| Session duration metrics | — |

Client timestamps may appear in event **metadata** for debugging — ignored for authority.

---

# Device identity (Gate 1 extension) ✅ FROZEN

**Decision policy for duplicate login:**

| Policy | Choice |
|--------|--------|
| Kick old session | ✅ **Default (frozen)** |
| Reject new session | ❌ Bad UX for legitimate device change |
| Transfer session | ❌ Complex; defer unless product requires |

**Rule:** New authoritative login **supersedes** prior session.

```
New device login
  → connectivity.session_superseded (old session_id)
  → Old session: presence=ended, operational=offline
  → New session: authoritative=true
```

Implemented in **M17 (Session Recovery)**. M14 schema must include `device_id`, `is_authoritative`, `superseded_by_session_id`.

---

# Single writer event types (reference)

Events accepted by `fn_driver_connectivity_transition` (expand per migration):

| Event | Migration | Writes |
|-------|-----------|--------|
| `session.start` | M14 | New session row |
| `heartbeat.received` | M15 | `last_heartbeat_at`, presence refresh |
| `transport.realtime` | M15 | `last_realtime_at` |
| `session.reconnect` | M16 | presence → present |
| `session.supersede` | M17 | authoritative swap |
| `presence.stale` | M18 | presence → stale (cron) |
| `operational.available` | M14+ | operational transition |
| `operational.offline` | M14+ | operational transition |

All emit audit events under `connectivity.*` namespace.

---

# Session observability (Program 2 subsystem)

Introduced in M14 — metrics and views only, not enforcement.

Track: active sessions · avg session duration · unexpected disconnects · duplicate logins · reconnect success rate · avg reconnect time · presence transitions/min · legacy drift.

See [PHASE-4-M14-DESIGN.md §8](./PHASE-4-M14-DESIGN.md#8-session-observability-m14).

---

**New operational KPI:**

```
Platform says: Available
Reality:       Driver app confirms available
Accuracy:      98.7%
```

**Measurement (during observation):**

- Sample drivers with authoritative session + heartbeat fresh
- Compare platform operational state vs client-reported state (telemetry)
- Track false online (platform says available, driver isn't) and false offline

Target for Program 2 closure: **≥ 98%** truth accuracy over 7-day window across rush hour, weekend, night.

---

# Observation windows

| Program | Window | Rationale |
|---------|--------|-----------|
| Program 1 (Billing) | 48 hours | Financial events cluster quickly |
| **Program 2 (Connectivity)** | **7 days** | Morning rush, weekend, night, charging, poor signal patterns |

Each migration (M14–M18) has its own sub-window inside the program — minimum **48h per migration**, **7 days before M18 enforce**.

---

# Program 2 closure — stress test (mandatory)

Before Program 2 executive closure:

```
100 simulated drivers
  → Network interruptions
  → Reconnects
  → Background / foreground
  → Heartbeat loss
  → Session supersede
  → Recovery
  → Dispatch candidate pool check
```

Pass criteria: truth accuracy ≥ 98%, no duplicate authoritative sessions, dispatch pool matches expected eligible count.

Script location (TBD): `scripts/connectivity/stress_program2_closure.sh`

---

# Gate checklist — M14 unlock

| Gate | Status | Blocks M14 SQL |
|------|--------|----------------|
| 1 Session model (`driver_sessions`) | ✅ Frozen | — |
| 2 Presence (Realtime + Heartbeat) | ✅ Frozen | — |
| 3 Explicit state machine + transition table | ✅ Frozen | — |
| 4 Single writer (`fn_driver_connectivity_transition`) | ✅ Frozen | — |
| 5 Failure + recovery strategy | ✅ Frozen | — |
| 6 Time authority (server `now()` only) | ✅ Frozen | — |
| Device identity policy | ✅ Frozen (supersede) | — |
| Session observability | ✅ Defined (M14) | — |
| `PHASE-4-M14-DESIGN.md` reviewed | ✅ Approved | — |
| Repo migrations M14A–E | ✅ In repo | — |
| CTO sign-off on M14 production | ☐ Pending | **Yes** |

**Design artifact:** [PHASE-4-M14-DESIGN.md](./PHASE-4-M14-DESIGN.md) — DDL proposal, events, transitions, sequences, smoke, rollback, observation.

---

# CTO decision log

| Date | Decision |
|------|----------|
| 2026-06-25 | Program 2 approved; M14 blocked until architecture gates frozen |
| 2026-06-25 | Gates 1–6 + session observability frozen |
| 2026-06-25 | `PHASE-4-M14-DESIGN.md` published (design-only) |
| 2026-06-25 | 7-day observation window for connectivity |
| 2026-06-25 | Stress test required for Program 2 closure |

---

*Architecture frozen. M14 design published — awaiting CTO review. No migration until approved.*
