# HeyCaby Shift Certification

**Program:** 1.5 — Launch Validation  
**Also called:** Launch Validation Week  
**Question this answers:** Can a real taxi driver work an entire shift in Rotterdam using HeyCaby?

> Stop building new features until this checklist passes on a **physical device** with a **real Supabase backend** (no Go dependency for runtime).

---

## Governance placement

Permanent release pipeline (insert after Observation, before GA):

```
Architecture → Design → Repository → RC1 → RC2 → Production → Observation
  → SHIFT CERTIFICATION ✅ → GA → LTS → Freeze
```

**Rule:** No program (Connectivity, Dispatch, etc.) may declare GA until Shift Certification passes for the driver app in the target launch market (Rotterdam / NL).

---

## How to run

| Item | Detail |
|------|--------|
| **Device** | Physical iPhone, iOS 18+, release or `--release` device build |
| **Account** | Real driver profile (or review account only for App Store path) |
| **Duration** | Minimum one full simulated shift (~4h focused test); ideal: full day |
| **Recorder** | One person drives; one person ticks boxes + captures screenshots/logs |
| **Fail policy** | Any ☐ in Phases 1–10 blocks GA; log issue → fix → re-run affected phase |

### Runtime sanity (every phase)

After any mutation (go online, ride complete, payment, verification, reconnect):

- App calls `fn_driver_runtime` (directly or via `refreshDriverRuntime`)
- Response has `runtime_version: 3`, fresh `generated_at`, `ok: true`

---

## Phase 1 — App open

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Runtime loads | Splash → home without crash; no Go API errors in logs |
| ☐ | Runtime version | `runtime_version === 3` in RPC response |
| ☐ | Timestamp current | `generated_at` within last ~60s of fetch |
| ☐ | Session restored | Auth session valid; driver row exists |
| ☐ | Billing loaded | `runtime.billing` present; status matches billing screen |
| ☐ | Feature flags | `runtime.config.feature_flags` present (e.g. `driver_onboarding_v2`) |
| ☐ | Connectivity state | `runtime.connectivity` present; no RPC error |

---

## Phase 2 — Go online

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Plate valid | `runtime.onboarding.plate_verified` or plate onboarding complete |
| ☐ | Terms accepted | Terms + indemnification if required by checklist |
| ☐ | Billing OK | `runtime.billing.can_accept_rides` or billing gate UI → pay → refresh |
| ☐ | Runtime refreshed | After go-online attempt, snapshot updated |
| ☐ | Driver on map | Rider/admin can see driver location (if test rider available) |
| ☐ | GPS uploading | `driver_locations` row updates (Supabase) |
| ☐ | Heartbeat alive | `driver_sessions.last_heartbeat_at` advances (if M14 session active) |

**RPC:** `fn_driver_set_status('available', lat, lng)` — must not fall back to Go.

---

## Phase 3 — Ride offer

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Offer arrives | Push and/or in-app offer screen |
| ☐ | Correct sound | `ride_request_incoming` (driver channel) |
| ☐ | Countdown | Timer visible; expires correctly |
| ☐ | Accept | Accept → ride status `accepted` |
| ☐ | Other drivers rejected | Offer closed for other drivers |
| ☐ | Rider notified | Rider push / in-app driver found |

---

## Phase 4 — Navigation

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Waze opens | External nav from ride screen |
| ☐ | Correct destination | Pickup then dropoff addresses match ride |
| ☐ | Return to app | App resumes; ride state intact |
| ☐ | Ride preserved | Same `ride_id`, status not lost |

---

## Phase 5 — Pickup

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Outside ping | Driver ping → rider notification |
| ☐ | Rider special notification | Rich ping UX (sound, haptic, alert) |
| ☐ | Chat works | Driver ↔ rider messages deliver |
| ☐ | Arrival detected | Manual or geo arrival → correct status |
| ☐ | Start ride | Status → in progress |

---

## Phase 6 — Trip

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | GPS updates | Driver location stream during trip |
| ☐ | Rider map updates | Rider sees driver movement |
| ☐ | Runtime stable | No duplicate runtime storms; cache invalidates on events |
| ☐ | Background survive | App backgrounded 2+ min; state recovers |
| ☐ | Lock / unlock | Phone locked mid-ride; unlock → ride UI restored |

---

## Phase 7 — Destination

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Auto-arrival | Near destination triggers arrival UX (if enabled) |
| ☐ | Complete ride | Complete flow finishes; status terminal |
| ☐ | Ledger +€1 | Platform fee accrual in billing ledger (if applicable) |
| ☐ | Runtime refresh | `completed_rides` / milestones update after complete |
| ☐ | Milestone updates | Progressive verification banner reflects new ride count |
| ☐ | Ride history | Ride appears in driver history / detail |

---

## Phase 8 — Shift recovery

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Kill app | Force quit during active ride or while online |
| ☐ | Reopen app | Cold start |
| ☐ | Active ride restored | Routed to correct ride screen |
| ☐ | Shift restored | Online/break/offline state correct |
| ☐ | Earnings restored | Shift stats / today earnings plausible |
| ☐ | Online restored | If was online, still online or clear prompt |

---

## Phase 9 — Connectivity

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Airplane mode | Toggle on while online |
| ☐ | Reconnect | Toggle off; app recovers without manual re-login |
| ☐ | GPS resumes | Location updates resume |
| ☐ | Runtime refresh | Post-reconnect runtime fetch succeeds |
| ☐ | Dispatch resumes | Eligible for offers again when online + billing OK |

---

## Phase 10 — Finish shift

| ☐ | Check | Pass criteria |
|---|--------|----------------|
| ☐ | Go offline | Swipe / toggle offline |
| ☐ | Runtime refresh | Offline reflected in runtime |
| ☐ | Shift stored | Shift session ended; stats persisted |
| ☐ | History correct | Today's rides match completed count |
| ☐ | Billing correct | Outstanding / grace / locked matches reality |
| ☐ | Platform healthy | `runtime.platform_health` GOOD or expected state |

---

## Chaos tests (run after Phases 1–10 pass once)

Mark each: **Pass** / **Fail** / **N/A** + notes.

| ☐ | Scenario | Expected recovery |
|---|----------|-------------------|
| ☐ | Phone battery dies mid-ride | Restore → ride or summary screen |
| ☐ | Phone reboot | Same as kill app (Phase 8) |
| ☐ | Internet disappears 5+ min | Graceful offline UX; reconnect |
| ☐ | Waze crashes | Return to HeyCaby; ride intact |
| ☐ | Driver rejects ride | Offer cleared; ready for next |
| ☐ | Rider cancels en route | Driver notified; returned to online/waiting |
| ☐ | Driver force-closes during offer | No ghost accepted ride |
| ☐ | Notification during phone call | No crash; tap opens correct screen |
| ☐ | Two notifications at once | Both handled; no duplicate accept |
| ☐ | GPS freezes | Stale location detected or user prompt |
| ☐ | Change language (NL ↔ EN) | UI + runtime notices coherent |
| ☐ | Rotate phone | Layout OK on supported orientations |
| ☐ | Incoming WhatsApp / cellular call | App pauses/resumes safely |
| ☐ | Bluetooth disconnect | Audio/nav handoff acceptable |

---

## Sign-off

| Role | Name | Date | Result |
|------|------|------|--------|
| Driver tester | | | ☐ Pass ☐ Fail |
| Engineering | | | ☐ Pass ☐ Fail |
| CTO | | | ☐ Pass ☐ Fail |

**Certification ID:** `SHIFT-ROTTERDAM-___`  
**Build:** driver `___` · Supabase project `fvrprxguoternoxnyhoj` · `runtime_version` 3

When all three sign Pass → update [HEYCABY-MASTER-TRACKER.md](../HEYCABY-MASTER-TRACKER.md) Program 1.5 → ✅ and unblock Program 2 GA work.

---

## Related docs

- Runtime contract: `supabase/migrations/20260619180000_v1_driver_runtime_v3_modular_contract.sql`
- Smoke SQL: `scripts/sql/smoke_driver_runtime.sql`
- App Store runtime notes: `apps/driver/docs/APP_STORE_REVIEW_NOTES_SERVER_DRIVEN.md`
- Ride state machine: `apps/driver/docs/RIDE_STATE_MACHINE.md`
