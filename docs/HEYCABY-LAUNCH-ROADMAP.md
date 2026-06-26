# HeyCaby Launch Roadmap (Final)

**Status:** Frozen program order — do not reorder without TRB + Product sign-off  
**Question this answers:** *What order gives us the highest chance of a flawless launch?*  
**Last updated:** 2026-05-19

---

## Principle

Stop asking **"What should we build?"**  
Start asking **"What order gives us the highest chance of a flawless launch?"**

Features are grouped into **Programs**. Programs ship in sequence. **Program 4 (Premium UI) does not start until Program 3 is certified.**

---

## Program stack

```
Program 1  Backend Foundation          ✅ COMPLETE
Program 2  Driver Connectivity         🚧 IN PROGRESS (M14 RC1)
Program 3  Operational Readiness       ✅ core (3A–3E); Gold cert pending
Program 4  Premium Driver UI/UX        ⏳ AFTER Program 3
Program 5  Rider Experience            ⏳ AFTER Program 4
Program 6  Launch                      ⏳ FINAL GATE
Program 7  Scale (multi-country)       ⏳ AFTER product–market fit
```

**Also complete (parallel track):** Billing & Governance (LTS) — see [PLATFORM-PLAYBOOK.md](./PLATFORM-PLAYBOOK.md).

---

## Program status board

| Program | Mission | Status |
|---------|---------|--------|
| **1 — Backend Foundation** | Audit log, RLS, RPC discipline, migration safety | ✅ Complete |
| **Billing & Governance** | Ledger, eligibility, accept enforcement, platform health | ✅ Complete · LTS |
| **2 — Driver Connectivity** | Sessions, events, heartbeat, presence truth | 🚧 M14 RC1 |
| **3 — Operational Readiness** | 12-hour shift without breaking the app | 🚧 **Active** |
| **4 — Premium Driver UI** | Redesign **finished** flows only | ⏳ Blocked on P3 |
| **5 — Rider Experience** | Rider parity + sync contract | ⏳ Blocked on P4 |
| **6 — Launch** | App Store, ops, support, monitoring | ⏳ Final gate |
| **7 — Scale** | Multi-market, dispatch intelligence, consolidation | ⏳ Post-PMF |

---

## Program 3 — Operational Readiness

**Mission:**

> Can a professional driver complete a 12-hour shift without breaking the app?

This is **not** a UI audit. It is an **operational behavior** program.

**Contract docs:**

| Document | Role |
|----------|------|
| [RIDE_STATE_MACHINE.md](../apps/driver/docs/RIDE_STATE_MACHINE.md) | States, transitions, screens, notifications |
| [OPERATIONS-PLAYBOOK.md](./OPERATIONS-PLAYBOOK.md) | Support procedures, SQL, incident response |
| [GAP-IMPLEMENTATION.md](../GAP-IMPLEMENTATION.md) | Bolt-benchmark UX gaps (post-P3 polish) |

### Exit criteria (Program 3 complete)

- [ ] All **3A–3E** mini-programs certified **Gold**
- [ ] **Launch Certification** simulation passed (see below)
- [ ] No open **P0** items in RIDE_STATE_MACHINE §0 Level 1
- [ ] TRB PRR signed for driver operational release

---

### Program 3A — Driver Tracking

**Scope:** Everything related to location.

| Deliverable | Description | Status |
|-------------|-------------|--------|
| Continuous GPS while online | Wire `DriverLocationService.startTracking()` | ✅ |
| 5s location upsert | `driver_locations` + country/zone | 🚧 |
| Foreground permission flow | Already on go-online | ✅ |
| Background location (iOS/Android) | Entitlements + policy copy | 🚧 |
| App killed / reboot | Resume tracking after shift restore | 🚧 |
| Heartbeat / connectivity events | `fn_driver_connectivity_transition` client emit | 🚧 |
| Reconnect UX | Banner + retry (Program 3E overlap) | ✅ 3E |

**Owner:** Flutter + M14 connectivity  
**Verify:** Driver online 30 min → `driver_locations.updated_at` advances every ~5s

---

### Program 3B — Ride & Shift Recovery

**Scope:** Cold start restores the driver's **day**, not just auth.

| Deliverable | Description | Status |
|-------------|-------------|--------|
| Active ride restore | Fetch in-progress `ride_requests` → route + `setActiveRide` | ✅ 3B |
| Shift restore | `drivers.status`, `current_shift_id`, timers | Partial — status + stats refetch |
| Earnings restore | Today counters from server | Partial — provider invalidation |
| Navigation context restore | Pickup/dest coords from ride row | ✅ 3B |
| Wait timer restore | Pickup wait from `driver_arrived` timestamp | ⏳ |

**Owner:** Flutter bootstrap (`app.dart` + session service)  
**Verify:** Kill app mid-`in_progress` → reopen on progress screen within 5s

---

### Program 3C — Communications Layer

**Scope:** Bigger than FCM — all driver↔rider↔platform signals.

| Deliverable | Description | Status |
|-------------|-------------|--------|
| FCM foreground handler | Route + sound by category | ✅ 3C |
| FCM background tap | Deep link to ride/chat | ✅ 3C |
| FCM cold start | `getInitialMessage()` | ✅ 3C |
| Rider cancel → full-screen modal | Not snackbar | ✅ 3C |
| Offer haptics | Heavy impact on invite | ✅ 3C (FCM + realtime) |
| In-ride chat | Active trip + progress | Partial |
| Nudge rider ("outside") | API exists | ✅ |
| Call rider | `tel:` from ride flow | ⏳ |
| SMS fallback | Future | ⏳ |
| Notification actions | Accept from tray (future) | ⏳ |

**Owner:** Flutter + driver-agent notify rules  
**Verify:** Background push tap opens correct ride screen

---

### Program 3D — Navigation Subsystem

**Scope:** External nav handoff + future proximity.

| Deliverable | Description | Status |
|-------------|-------------|--------|
| Waze default (NL) | Shared launcher | ✅ 3D |
| Google Maps fallback | Native → web | ✅ 3D |
| Settings preference | `nav_app_pref` | ✅ 3D |
| Nav on active trip | Pickup | ✅ 3D |
| Nav on in-progress | Destination | ✅ 3D |
| Auto-arrival (100–300 m) | Assist only; manual override | ✅ L2 |
| Destination proximity | Complete assist | ✅ L2 |
| Apple Maps / TomTom / HERE | Post-launch | ⏳ |

**Owner:** Flutter shared `DriverNavigationLauncher`  
**Verify:** Tap Navigate → Waze opens with destination pre-filled, no paste

---

### Program 3E — Resilience

**Scope:** Everything bad that can happen.

| Scenario | Required behavior | Status |
|----------|-------------------|--------|
| Internet dies | Banner, queue actions, retry | ✅ 3E |
| GPS dies | Block go-online; warn if lost mid-shift | ✅ 3E |
| Phone dies / reboot | 3B recovery | ✅ ride; partial shift |
| Battery optimization kill | Android exemption prompt | ⏳ |
| Passenger cancels | Modal + clear state | ✅ 3C |
| Driver cancels | Pre-pickup dialog | ✅ |
| Offer expires | Timeout + missed dialog | ✅ |
| Accept fails (billing) | Gate message | ✅ |
| Duplicate session | Force logout modal | ⏳ |
| Server reconnect | Realtime resubscribe | ✅ 3E |

**Owner:** Flutter + ops procedures in OPERATIONS-PLAYBOOK  
**Verify:** Launch simulation script (below)

---

## Program 4 — Premium Driver UI

**Starts only when Program 3 exit criteria are met.**

Redesign **stable** workflows from [SCREEN_OWNERSHIP.md](../apps/driver/docs/SCREEN_OWNERSHIP.md). Do not redesign flows still changing under 3A–3E.

---

## Launch Certification

No feature bypasses certification. Objective gate — not intuition.

| Tier | Meaning | Required for |
|------|---------|--------------|
| **Gold** | Backend + connectivity + unit/smoke + maps to RIDE_STATE_MACHINE | Merge to `main` for operational code |
| **Launch** | Survives full-day driver simulation; no critical failures | TestFlight external / soft launch |
| **Production** | TRB PRR + observation window + support playbook staffed | App Store Netherlands |

### Gold checklist (per mini-program)

- Code merged with tests or smoke SQL where applicable  
- RIDE_STATE_MACHINE updated if states changed  
- OPERATIONS-PLAYBOOK updated if new incident class  
- Static analysis clean on touched paths  

### Launch checklist

- [ ] Launch simulation script executed on physical device(s)  
- [ ] Datadog / logs reviewed — zero unhandled ride state orphans  
- [ ] Support trained on OPERATIONS-PLAYBOOK top 10 incidents  

---

## Launch Test — Full-day simulation

**Not** smoke. **Not** unit. A real-world torture test before Apple submission.

Execute on **physical iPhone**, release build, production-like backend.

| Time | Event | Pass criteria |
|------|-------|---------------|
| 08:00 | Driver logs in | Session hydrate; home loads |
| 08:05 | Go online | Gates pass; GPS tracking starts |
| 08:15 | Accept ride | Offer → active trip; sound |
| 08:25 | **GPS lost** | Banner; no crash |
| 08:28 | **GPS restored** | Tracking resumes; location rows update |
| 08:31 | **Passenger cancels** | Full-screen modal; home; no ghost ride |
| 08:40 | Accept second ride | Normal flow |
| 09:05 | **Phone reboot** | |
| 09:07 | Reopen app | **Ride restored** on correct screen |
| 09:30 | Complete trip | Receipt + rate |
| 09:45 | Billing threshold (€60) | Block accept / go-online with clear UX |
| 09:50 | Payment (Mollie/IAP) | Gate clears |
| 09:52 | Resume online | Shift continues; earnings preserved |
| 11:00 | 20 rides completed | No memory leaks; shift stats sane |
| 12:00 | Break 15 min | Break timer; no invites |
| 20:00 | End shift | Session closed; offline |

**Record:** screen recording + driver_id + session_id + export connectivity events for postmortem.

---

## Document ecosystem

```
PRODUCT-PRINCIPLES.md         → why we exist & what we refuse (product)
ENGINEERING-BIBLE.md          → how engineers work
TECHNICAL-REVIEW-BOARD.md     → how changes are approved
PLATFORM-PLAYBOOK.md          → how the platform evolves
RIDE_STATE_MACHINE.md         → ride contract (product + eng)
OPERATIONS-PLAYBOOK.md        → how support resolves incidents
HEYCABY-LAUNCH-ROADMAP.md     → program order + certification
```

**Governance is frozen.** No new process docs — improve these or write code.

---

## What not to do

- Do **not** start Program 4 UI redesign while 3A–3E P0 items remain open  
- Do **not** add growth features (Program 7) before Launch Certification  
- Do **not** ship new ride states without TRB + RIDE_STATE_MACHINE update  

---

*Discipline through Program 3 is the moat. Premium UI on stable ops ships faster than premium UI on moving targets.*
