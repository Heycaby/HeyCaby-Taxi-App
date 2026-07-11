# HeyCaby Rider — Live Widget (Live Activity)

> **Product frame:** The rider Live Activity is a **mini ride timeline + waiting fee assistant** — not a generic “Live ride” badge. It is a **personal travel assistant** on the lock screen that answers the rider’s next questions without unlocking the phone.

**Platform:** iOS Live Activity + Dynamic Island (`HeyCabyWidgetsExtension`)  
**Flutter sync:** `apps/rider/lib/services/rider_notify_live_activity.dart`  
**Waiting model (client read-only):** `apps/rider/lib/models/ride_waiting_info.dart`  
**Native UI:** `apps/rider/ios/HeyCabyWidgets/HeyCabyWidgetsLiveActivity.swift`  
**Deep link:** `heycabyrider://ride-status`

---

## CTO decision

**Yes — add the progress bar and waiting timer.**

This makes HeyCaby feel transparent and professional. The lock screen should tell the rider, in order:

1. Your driver is coming.  
2. Your driver is outside.  
3. You have 2 minutes free.  
4. Waiting fee has started.  
5. Your ride is underway.  
6. Payment is complete.

**Target experience:** 10× rider clarity vs a static “Live ride” label.

---

## Goal

The widget must always answer:

| # | Question |
|---|----------|
| 1 | **What is happening now?** |
| 2 | **How long do I have?** |
| 3 | **What should I do next?** |
| 4 | **Am I about to be charged waiting time?** |

Plus the original four locked-phone questions:

| # | Question |
|---|----------|
| A | Has a driver been found? |
| B | Where is my driver? |
| C | How long until pickup (or destination)? |
| D | Do I need to do anything? |

**Current gap:** Lock screen showed only `HeyCaby` + `🚕 Live ride` — answered none of the above.

---

## Ride states (canonical)

Eight phases for progress + copy (nearby/outside split; outside splits again for free vs paid wait):

1. **Searching**  
2. **Driver found**  
3. **Driver on the way**  
4. **Driver nearby**  
5. **Driver outside — free wait**  
6. **Driver outside — paid wait** (same progress segment as free wait)  
7. **On trip**  
8. **Payment**  
9. **Completed** (end Live Activity)

---

## Progress bar (percent-based)

Give riders confidence without opening the app. Use a **single continuous bar** (8 segments visually, or smooth fill by percent).

| State | Progress | Bar (8 blocks) |
|-------|----------|----------------|
| Searching | 15% | `■■□□□□□□` |
| Driver found | 30% | `■■■□□□□□` |
| On the way | 45% | `■■■■□□□□` |
| Nearby | 60% | `■■■■■□□□` |
| Outside (free or paid wait) | 70% | `■■■■■■□□` |
| On trip | 85% | `■■■■■■■□` |
| Payment | 95% | `■■■■■■■■` |
| Completed | 100% | dismiss activity |

**Payload:** `progressPercent` (0–100) and/or `timelineStep` (legacy 0–4) — prefer percent for Swift UI.

---

## Lock screen examples (target copy)

### Searching

```
🔍 Looking for driver
5 drivers notified
■■□□□□□□
Next: We're notifying nearby drivers.
```

### Driver found

```
🚕 Ahmed accepted
Black Tesla Model Y
Pickup in 7 min
■■■□□□□□
Next: Meet your driver at the pickup point.
```

### Driver on the way

```
🚕 Pickup in 6 min
TX-22-NL · Black Tesla
■■■■□□□□
Next: Ahmed is heading to you.
```

### Driver nearby

```
📍 Driver nearby
Please head to pickup
■■■■■□□□
Next: Please head downstairs.
```

### Driver outside — free wait

```
🚖 Driver outside
Free wait: 1:42 left
■■■■■■□□
Next: Look for Black Tesla Model Y · TX-22-NL.
```

Countdown examples: `2:00` → `1:30` → `0:45` → `0:10`

### Driver outside — paid wait

```
⏱ Waiting fee active
€0.80 added
■■■■■■□□
Next: Please join your driver at the pickup point.
```

Updates: `€0.40 added` → `€0.80 added` → `€1.20 added` (not every second — see throttling).

### On trip

```
🚕 On your way
Arriving in 18 min
■■■■■■■□
Next: Relax — we'll keep you updated.
```

### Payment

```
💳 Payment
Waiting for confirmation
■■■■■■■■
Next: Confirm payment with your driver.
```

### Completed

```
✅ Payment received
Thank you for riding with HeyCaby.
```

→ **Close Live Activity** after payment/rating flow.

---

## Waiting timer rules

### Policy

- Riders get **2 minutes (120 s) free waiting time** after the driver taps **I have arrived**.
- Backend starts the waiting clock; **Supabase is source of truth** — do not calculate waiting fee only in Flutter.
- When the trip starts, **freeze** waiting fee on the ride row.

### Trigger

When driver taps **I have arrived**:

- `driver_arrived_at = now()` (ride row)  
- `waiting_grace_seconds = 120`  
- `waiting_rate_per_minute` / snapshot from driver tariff  

### During free wait

While `seconds_since_arrival < waiting_grace_seconds`:

- Live Activity: **`Free wait: M:SS left`**
- Friendly tone — never lead with money

### After free wait

```
chargeable_seconds = seconds_since_arrival - waiting_grace_seconds
waiting_fee_cents ≈ f(chargeable_seconds, waiting_rate_per_minute)
```

- Live Activity: **`Waiting fee active`** + **`€X.XX added`**
- Update on meaningful intervals (e.g. every 15–30 s or when fee crosses €0.20 steps) — **do not spam every second**

### At ride start

- Freeze fee server-side (`waiting_fee_finalized_at` / frozen columns on ride).
- Live Activity switches to **on-trip ETA**; waiting timer removed from lock screen.

### Why this matters

| Stakeholder | Benefit |
|-------------|---------|
| **Drivers** | Waiting time respected |
| **Riders** | Warned before charges; no surprise fees |
| **HeyCaby** | Fewer payment disputes; feels fair |

The lock screen **politely pushes the rider to move** when the driver is outside.

---

## Backend source of truth (Supabase)

Live Activity reads ride state from **backend fields** (realtime poll or push-triggered sync). Do not invent waiting math only on device.

### Ride row fields (repo / CTO mapping)

| CTO / concept | App / DB field (current repo) |
|---------------|-------------------------------|
| Driver arrived | `driver_arrived_at` |
| Free grace period | `waiting_grace_seconds` (default 120) |
| Waiting started | implied by `driver_arrived_at` |
| Chargeable seconds | `chargeable_wait_seconds` (frozen) or derived live |
| Waiting fee | `waiting_fee_cents` |
| Rate snapshot | `waiting_rate_per_minute` |
| Waived | `waiting_fee_waived` |
| Fee frozen at trip start | server RPC on start trip |

Additional columns referenced in migrations: `waiting_started_at`, `waiting_rate_snapshot`, `waiting_fee_finalized_at`, `waiting_fee_waived_at`, etc.

### Client model

`RideWaitingInfo` (`apps/rider/lib/models/ride_waiting_info.dart`):

- Parses ride row JSON  
- `remainingGraceSecondsNow()`, `waitingFeeCentsNow()`, `isInGracePeriod`  
- Formula aligned with `fn_driver_start_trip`  

**Live Activity sync** already accepts `RideWaitingInfo?` in `syncActiveRide` — extend to drive lock-screen copy and `graceRemaining` / `waitFee` payload keys.

---

## Notification timing (push + Live Activity)

Use push for moments the rider might miss; Live Activity holds persistent state.

| Event | Push copy (example) | Live Activity |
|-------|---------------------|---------------|
| Driver nearby | “Your driver is nearby. Please head to pickup.” | Nearby state + progress 60% |
| Driver arrived | “Your driver is outside. You have 2 minutes free waiting time.” | Outside + free countdown |
| 30 s grace left | “Free waiting ends in 30 seconds.” | Free wait `0:30` |
| Paid wait starts | “Waiting fee has started.” | Paid wait + € added |
| (On trip / payment) | sparingly | ETA / payment on widget |

**Rule:** Do not spam every second on push or Live Activity updates.

---

## Important UX rule — money tone

**Never scare the rider with money too early.**

| Phase | Tone |
|-------|------|
| Outside, in grace | “Your driver is outside. **Free wait: 1:42 left.**” |
| After grace | “**Waiting fee active.** €0.80 added.” |

Clear, fair, not aggressive.

---

## Dynamic Island

Compact states (tap expands full Live Activity):

| Phase | Compact trailing examples |
|-------|---------------------------|
| En route to pickup | `🚕 6 min` |
| Free wait | `⏱ 1:42 free` |
| Paid wait | `€0.80 wait` |
| On trip | `📍 18 min` |
| Searching | `🔍 3 notified` |

**Keyline tint:** HeyCaby green (`#00A651` / `#34D399`).

---

## “Next action” line

Always show **what to do next** under the progress bar:

| State | Next action |
|-------|-------------|
| Searching | “We're notifying nearby drivers.” |
| Driver found | “Meet your driver at the pickup point.” |
| On the way | “Ahmed is heading to you.” |
| Nearby | “Please head downstairs.” |
| Outside | “Look for Black Tesla Model Y · TX-22-NL.” |
| On trip | “Relax — we'll keep you updated.” |
| Payment | “Confirm payment with your driver.” |

---

## Automatic state machine

```
Searching?           → progress 15%, drivers notified
Driver accepted?     → progress 30%, name + car + pickup ETA
Driver close?        → progress 45–60%, get ready
Driver arrived?      → progress 70%, free wait countdown
Grace expired?       → same segment, paid wait € line
Trip started?        → progress 85%, destination ETA (no wait timer)
Payment?             → progress 95%
Done?                → 100%, end activity
```

---

## Ping / chat integration (v2 differentiator)

Surface latest driver ping on lock screen without opening chat:

```
📨 Ahmed: I'm on my way.
📨 Ahmed: I'm outside.
```

Payload: `pingLine`, `pingFrom`. Rate-limit updates.

---

## Payload contract (Flutter → App Group)

| Key | Purpose |
|-----|---------|
| `title` | Primary headline |
| `subtitle` | Route, driver+car, destination |
| `status` | Secondary line (fee state, search detail) |
| `eta` | Pickup or trip ETA string |
| `progressPercent` | **(planned)** 15–100 |
| `timelineStep` | Legacy 0–4 (keep until Swift uses percent) |
| `nextAction` | Rider instruction line |
| `driversNotified` | Search social proof |
| `graceRemaining` | `M:SS` free wait (maps to Swift `graceRemaining`) |
| `totalFare` | Running total at pickup if shown |
| `waitFee` | `+€X.XX` or “€X.XX added” |
| `waitPhase` | `free` \| `paid` \| `none` |
| `pingLine` | Latest chat one-liner |

Swift: `HeyCabyWidgetsLiveActivity.swift` reads via `LiveActivitiesAppAttributes.prefixedKey(...)`.

---

## Implementation status

| Area | Status | Notes |
|------|--------|-------|
| Live Activity shell | ✅ | iOS 18+, widget extension |
| Brand styling (green, progress track) | 🟡 | Swift redesign started |
| `RideWaitingInfo` + in-app waiting UI | ✅ | `active_ride_screen`, `rider_waiting_fee_card` |
| `syncActiveRide` + grace/fee payload | 🟡 | Partial — needs phase copy + percent |
| Eight-state progress percent | 🔲 | Not implemented |
| Nearby / outside geofence | 🔲 | Needs driver location + thresholds |
| Push copy at grace milestones | 🔲 | `ride_flow_notify_lifecycle_rpcs` exists |
| Payment phase on lock screen | 🔲 | |
| `nextAction` + `progressPercent` | 🔲 | |
| Android equivalent | 🔲 | Separate track |

---

## Acceptance criteria (definition of done)

- [ ] Rider books ride → Live Activity starts (searching, ~15% progress).
- [ ] Progress bar advances through ride states (15 → 30 → 45 → 60 → 70 → 85 → 95 → 100).
- [ ] **Driver accepted** updates lock screen (name, car, pickup ETA).
- [ ] **Driver nearby** updates lock screen + optional push.
- [ ] **Driver arrived** starts **2-minute free wait** countdown on lock screen.
- [ ] Free wait shows `Free wait: M:SS left` and counts down.
- [ ] After 2 minutes, **paid waiting** shows `Waiting fee active` + € added (throttled updates).
- [ ] Waiting fee **freezes** when ride starts; on-trip ETA replaces wait timer.
- [ ] **Payment** state after ride completion.
- [ ] Live Activity **closes** after payment / rating flow complete.
- [ ] Waiting fee values match **Supabase** (not client-only math).
- [ ] Push sent at: nearby, arrived, 30 s grace left, paid wait start (not spam).

---

## Build roadmap

### Phase A — Model & payload (1–2 days)

- [ ] `LiveRidePhase` enum + `progressPercent` mapping.
- [ ] Map dispatch/ride status → title, subtitle, eta, nextAction, waitPhase.
- [ ] Wire `RideWaitingInfo` → Live Activity on every realtime tick (throttled).
- [ ] Honest search copy; driver count when available.

### Phase B — Native UI (1–2 days)

- [ ] 8-block or percent progress bar in Swift.
- [ ] Free wait vs paid wait layouts (icon + color).
- [ ] Dynamic Island compact strings per table above.
- [ ] Xcode previews for all states.

### Phase C — Triggers (3–5 days)

- [ ] Nearby: driver within ~1 km or ETA ≤ 2 min.
- [ ] Push notifications per timing table.
- [ ] End activity on terminal states.

### Phase D — Pings (optional)

- [ ] Chat/FCM → `pingLine` on widget.

### Phase E — QA

- [ ] Full device ride with phone locked at each phase.
- [ ] Verify waiting fee matches DB at grace boundary and trip start.

---

## Related files

```
apps/rider/lib/services/rider_notify_live_activity.dart
apps/rider/lib/models/ride_waiting_info.dart
apps/rider/lib/screens/active_ride_screen.dart
apps/rider/lib/widgets/active_ride/rider_waiting_fee_card.dart
apps/rider/ios/HeyCabyWidgets/HeyCabyWidgetsLiveActivity.swift
supabase/migrations/20260709190000_ride_flow_notify_fixes.sql
supabase/migrations/20260709190100_ride_flow_notify_lifecycle_rpcs.sql
```

---

## Open questions

1. **Driver count:** Exact “5 drivers notified” vs hide when zero?  
2. **Nearby threshold:** 1 km vs 500 m vs ETA-only?  
3. **Wait fee update interval on lock screen:** 15 s vs 30 s vs on €0.20 step?  
4. **Payment methods** on lock screen: all vs cash-first?  
5. **Dismiss timing:** After payment confirm vs after rating?  
6. **Ping on lock screen:** v1 or v2?

---

## CTO score

| Version | Score |
|---------|-------|
| “Live ride” only | ~4/10 |
| Current wired sync + basic UI | ~7.5/10 |
| **Target** (timeline + progress % + waiting assistant + next action) | **10/10** |

---

## Ride State Engine (sync architecture)

The Live Activity is a **first-class consumer** of backend ride state — not a one-shot decoration.

### One door (CTO rule)

**Every trigger** converges on a single function. ActivityKit is updated in **one place only**.

```
                    ┌─────────────────────────────────────────┐
  Realtime UPDATE   │                                         │
  FCM (foreground)  │     refreshRideState()                  │
  FCM (background)  │            ↓                            │
  5s poll (safety)  │     fetch full ride_requests row        │
  app resume        │            ↓                            │
  grace tick (1s)   │     resolve lifecycle (status + ts)     │
  driver location   │            ↓                            │
                    │     rideVersion gate (updated_at ms)    │
                    │            ↓                            │
                    │     update Rider UI providers           │
                    │            ↓                            │
                    │     RiderNotifyLiveActivity             │
                    │       .createOrUpdateActivity()  ← ONLY │
                    └─────────────────────────────────────────┘
```

| File | Role |
|------|------|
| `rider_ride_state_refresh.dart` | **Single door** — fetch, resolve, version gate, ActivityKit |
| `rider_ride_state_engine.dart` | In-app orchestrator (Riverpod + booking + driver GPS) |
| `rider_live_activity_scope.dart` | Wires realtime / poll / resume → `refreshRideState()` |
| `main.dart` | Background FCM → `RiderRideStateBackgroundRefresh` (no Riverpod) |

**Answer: what triggers ActivityKit?**  
Only `RiderNotifyLiveActivity.createOrUpdateActivity()`, always reached via `refreshRideState()` (or `refreshLocalPresentation()` for grace/ETA ticks). Realtime, FCM, and poll are **inputs** — not separate update paths.

### `rideVersion` (ordering)

Monotonic version = `ride_requests.updated_at` in epoch milliseconds.

- Incoming version **&lt; last applied** → ignore (stale)
- Incoming version **= last applied** → ignore (duplicate)
- Grace/ETA ticks bypass version gate (same backend version, local clock)

Payload includes `rideVersion` for native debugging; Swift may ignore until APNs push lands.

### Lifecycle matrix (staging proof checklist)

Run one two-phone ride on **HeyCaby Staging** (`fdavszxncggswuiwggcp`). After each driver action, verify all columns.

| Driver action | RPC | DB fields | Realtime | Push (FCM) | Widget (LA) | Rider UI |
|---------------|-----|-----------|----------|------------|-------------|----------|
| Accept | `fn_driver_accept_ride_invite` | `status=accepted`, `driver_id`, `accepted_at` | UPDATE → `refreshRideState` | `driver_found` | ✅ | ✅ |
| On my way | `fn_driver_ride_en_route` | `status=driver_en_route` | UPDATE → refresh | `driver_en_route` | ✅ | ✅ |
| Ping | `driver_ping` RPC | audit only (no status) | — | `driver_ping_on_my_way` | ✅ via FCM refresh | ✅ |
| Nearby (~1 km) | `fn_maybe_notify_near_pickup_for_driver` | `near_pickup_notified_at` | UPDATE → refresh | `near_pickup` | ✅ | ✅ |
| Arrived | `fn_driver_ride_arrived` | `status=driver_arrived`, `driver_arrived_at`, `waiting_grace_seconds=120` | UPDATE → refresh | `driver_ping_arrived` / `ride_arrived` | ✅ + 1s grace tick | ✅ |
| Start | `fn_driver_ride_start` | `status=in_progress`, `started_at` | UPDATE → refresh | `trip_started` | ✅ | ✅ |
| Complete | `fn_driver_ride_complete` | `status=completed`, `completed_at` | UPDATE → refresh | `ride_completed` | ✅ | ✅ |
| Payment | `fn_ride_confirm_payment` | `payment_status=paid` | UPDATE → refresh | `payment` | ✅ → dismiss | ✅ |

**Debug logs per transition:**

```
[RideStateEngine] refreshRideState source=fcm ride=<id> rideVersion=<ms> effectiveStatus=driver_en_route
[RideStateEngine] resolvedPhase=on_the_way rideVersion=<ms> source=fcm
[RideStateEngine] liveActivity update phase=on_the_way status=...
```

**SQL audit snippet** (after each driver tap):

```sql
SELECT status, driver_id, accepted_at, driver_arrived_at, near_pickup_notified_at,
       started_at, completed_at, payment_status, waiting_grace_seconds,
       waiting_fee_cents, updated_at
FROM ride_requests WHERE id = '<ride_id>';
```

### Trigger priority (production target)

| Priority | Mechanism | When |
|----------|-----------|------|
| **1 (target)** | APNs Live Activity push | App suspended/killed — **Phase 2** |
| **2** | FCM → `refreshRideState` (incl. background handler) | App backgrounded |
| **3** | Supabase Realtime → `refreshRideState` | App foreground / brief background |
| **4 (safety net)** | 5s poll | Realtime/FCM missed — remove when (1) is live |

### Phase 2: APNs Live Activity push (not yet shipped)

Premium architecture for suspended app:

```
Driver RPC → ride_requests UPDATE → Edge Function (driver-agent)
    → APNs push (pushType: liveactivity) → Widget updates without app wake
```

**Client prep (done):** single activity id, payload shape, `rideVersion`, version gate.  
**Server work (TODO):** capture ActivityKit push token from `live_activities` plugin → store on rider identity → fan-out from `driver-agent` on lifecycle UPDATE.

### Full ride test matrix (CTO sign-off)

Lock rider phone after book. Widget must never go stale through:

Searching → Accept → Ping → Nearby → Arrived → 2:00 countdown → Waiting fee → Start → Navigation → Complete → Driver payment → Rider payment confirm → Receipt → Rating → Favorite driver

Wiring lives in `RiderLiveActivityScope` (app root) + `RiderRideStateRefresh` (single door).

### Consumer matrix (implementation status)

| Driver action | DB | Realtime | Push | Rider screen | Live Activity |
|---------------|-----|----------|------|--------------|---------------|
| Ride created / searching | ✅ | ✅ | ✅ | ✅ | ✅ via refreshRideState |
| Driver accepted | ✅ | ✅ | ✅ | ✅ | ✅ |
| On my way | ✅ | ✅ | ✅ | ✅ | ✅ |
| Nearby | ✅ | ✅ | ✅ | ✅ | ✅ |
| Arrived | ✅ | ✅ | ✅ | ✅ | ✅ + grace tick |
| Ride started | ✅ | ✅ | ✅ | ✅ | ✅ |
| Completed | ✅ | ✅ | ✅ | ✅ | ✅ |
| Payment confirmed | ✅ | ✅ | ✅ | ✅ | ✅ (completed payload) |

**Rule:** The widget never infers phase locally. It renders payload built from lifecycle resolver + waiting fields + driver profile RPC.

---

*Last updated: 2026-07-09 — living doc.*
