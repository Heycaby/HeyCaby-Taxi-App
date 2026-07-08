# HeyCaby Driver — Bolt-Inspired UI/UX Redesign (Design Spec)

> **Purpose.** Give Bolt drivers a familiar cockpit on HeyCaby **without relearning flows or changing business logic.** This is a **visual and container redesign only**: same routes, providers, RPCs, state machine — new layout, hierarchy, and modal behavior.
>
> **Ground rules**
> 1. **HeyCaby color palette** — `DriverColors` / `HeyCabyColorTokens` (`accent`, `card`, `text`, `error`, etc.). No Bolt forest-green hex values; **roles** map 1:1 (accent = primary CTA, error = destructive/end trip).
> 2. **Minimalist** — white/near-white surfaces, thin borders, soft shadows, one hero number per screen, no nested-card clutter.
> 3. **Map-first modal stack** — map never leaves during a ride; sheets stack and dismiss. Full screens only for Hub, History, Finance, Settings.
> 4. **Bolt muscle memory** — placement, copy structure, sheet heights, and CTA colors match Bolt; HeyCaby-only features (Return Mode, Platform Balance, 0% commission, Driver Hub tariffs) stay, but **tucked into expandable regions**, not removed.

---

## 0. Architecture shift (the biggest change)

### Today (HeyCaby driver)

```text
Home (map + draggable home sheet — busy)
  → full-screen Opportunity (offer)
  → full-screen En route / At pickup / In progress (each a page)
  → full-screen Complete → Rate
```

Each ride phase **navigates to a new screen** with a scrollable card floating over a decorative map gradient.

### Target (Bolt-like, HeyCaby tokens)

```text
┌─────────────────────────────────────────────────────────────┐
│  MAP — persistent layer (route line, pins, driver puck)        │
│  Floating: recenter · safety shield · (optional) demand hint   │
└───────────────────────────────┬─────────────────────────────┘
                                │
        ┌───────────────────────┴───────────────────────┐
        │  SHEET LAYER (fixed OR expandable)             │
        │  · Idle home peek                              │
        │  · Incoming offer (fixed, tall)                │
        │  · Active ride peek → pull up for Route details│
        │  · Overlays: chat, safety, break, cancel         │
        └───────────────────────────────────────────────┘
```

| Sheet type | When | Bolt analogue | HeyCaby implementation hint |
|---|---|---|---|
| **Fixed** | One decision / one status | Offer, driver-found wait, share-location, safety, cancel confirm | `showModalBottomSheet` + `isScrollControlled: false` or tight `DraggableScrollableSheet` with `maxChildSize == initialChildSize` |
| **Expandable** | Rich content, progressive disclosure | Route details, active ride “More”, vehicle-tier list (N/A driver) | `DraggableScrollableSheet` with handle; peek = hero + primary CTA |
| **Full screen** | Account / ledger / hub | Rides tab, Balance, Help | Keep `go_router` routes; restyle list rows to match sheet typography |

**Files to evolve (UI only):** `driver_ride_flow_common.dart`, `driver_opportunity_screen_body.dart`, `driver_navigation_focus_body.dart`, `driver_pickup_arrival_body.dart`, `driver_active_trip_body.dart`, `driver_home_sheet.dart`, `driver_map_floating.dart`.

---

## 1. Design system (HeyCaby skin, Bolt skeleton)

### 1.1 Color roles (do not import Bolt hex)

| Role | HeyCaby token | Use like Bolt |
|---|---|---|
| Primary CTA | `colors.accent` + `colors.onAccent` | Accept, Start trip, Go online |
| Destructive / End | `colors.error` + `colors.onError` | End trip, Cancel order, Emergency |
| Offline / stop shift | `colors.warning` or muted outline | Go offline (Bolt uses orange — use **warning** or outline primary, not error) |
| Surfaces | `colors.card`, `colors.bgAlt` | Sheet background, metric tiles |
| Text hierarchy | `text` / `textMid` / `textSoft` | Headline / body / caption |
| Route line | `colors.accent` | Pickup leg + trip leg polyline |
| Pickup pin | `colors.accent` | Green dot equivalent |
| Dropoff pin | `colors.error` or `text` | Red/black pin equivalent |

### 1.2 Typography & spacing

- **One hero line per sheet** — `typography.displaySmall` or `headingLarge`, weight 800–900.
- **Hero number** — fare or waiting timer: same size as Bolt’s `€21.80` / `01:15 Waiting`.
- **Secondary** — `bodyMedium` + `textMid`, max 2 lines.
- **Sheet padding** — `DriverSpacing.screenEdge` (16–22); **radius** — `DriverRadius.sheetTop` (28).
- **Drag handle** — 40×4 pill, `colors.border`, centered, 8px below sheet top (Bolt standard).

### 1.3 Buttons (reuse `DriverButton`, change placement only)

| State | Variant | Label source |
|---|---|---|
| Accept / Start trip | `primary` | `DriverStrings.accept` (localize via `_t`, not hardcoded Dutch) |
| End trip | **`destructive`** | Complete ride |
| Decline / Skip | `outline`, small, top-right pill | Existing skip copy |
| Stop new requests | `outline` in Route details sheet | Existing toggle |
| Go offline | `outline` or `warning` fill on home peek | Three-state toggle simplified visually |

### 1.4 Illustration

Bolt uses 3D clay icons. HeyCaby keeps **flat icons + real vehicle/rider data** unless you add a light illustration pack later. **Do not block launch on 3D assets** — use `CircleAvatar`, plate pill, and `Icons.local_taxi_rounded` in accent circles.

---

## 2. Flow-by-flow redesign

### §1 Online / Idle — Home

**Bolt:** map + demand heatmap + earnings popover + orange `Go offline` + bottom tabs + Offers strip.

**HeyCaby redesign**

```
┌──────────────────────────────────────────────┐
│  [Map — demand overlay stays]                 │
│                          [recenter] [shield]  │
│  ┌─────────────────────────────────────┐     │
│  │ Today €54.06          Weekly →  👁   │     │  ← tap opens earnings (existing modal)
│  └─────────────────────────────────────┘     │
│                                               │
│              (map heatmap / hotspots)         │
│                                               │
│  ╭─────────────────────────────────────────╮ │
│  │ ─── handle                               │ │
│  │  ● Online    [Return mode chip]          │ │  ← peek only
│  │  Scheduled (2) · Swap (1)  →             │ │
│  │  ┌─────────────────────────────────┐    │ │
│  │  │      Go offline                  │    │ │  ← single secondary CTA
│  │  └─────────────────────────────────┘    │ │
│  ╰─────────────────────────────────────────╯ │
│  Home · Work · Rides · Me                     │  ← keep HeyCaby tabs; match Bolt tab bar height
╰──────────────────────────────────────────────┘
```

**Changes vs today**
- Collapse `DriverHomeSheet` **peek** to: status pill + today earnings chip + one offline CTA. Move Return Mode, swap feed, community, verification into **expanded pull-up** (same data, less noise at glance).
- Earnings: **floating compact card** top-left (like Bolt popover), not buried in sheet.
- **Remove duplicate** online/status surfaces — one toggle, one earnings entry.
- Demand: keep `driver_hotspots` / on-map circles; style zones as **soft translucent accent/error gradients**, not loud nested cards.

**Logic unchanged:** `ThreeStateToggle`, `driverEarningsProvider`, `scheduledRidesProvider`, `driverReturnModeProvider`.

---

### §2 Ride offer — Incoming request

**Bolt:** full map with route; small Decline top-right; offer card with € hero, tags, rider ★, two legs; green Accept bottom.

**HeyCaby redesign — FIXED tall sheet (~55% screen), not full-page scroll card**

```
┌──────────────────────────────────────────────┐
│  MAP: route polyline + pickup/drop pins       │
│  badge on map: "8.3 km · 12 min" to pickup    │
│                          [Decline]  (small)   │
│  ╭─────────────────────────────────────────╮ │
│  │ 24s          [New request]               │ │
│  │                                          │ │
│  │        € 21.80                           │ │  ← MUST be real fare, never "Open fare"
│  │  Standard · Cash · 1.1x demand           │ │  ← chips from existing _MetricChip
│  │  Skipping won't affect this trip         │ │
│  │                                          │ │
│  │  ● 16 min · 17.1 km  Pickup address      │ │
│  │  ● 12 min · 8.3 km   Destination         │ │
│  │  Ruth · 4.9 ★                            │ │
│  │                                          │ │
│  │  ┌─────────────────────────────────┐    │ │
│  │  │         Accept                   │    │ │  accent fill
│  │  └─────────────────────────────────┘    │ │
│  ╰─────────────────────────────────────────╯ │
╰──────────────────────────────────────────────┘
```

**Changes vs today (`driver_opportunity_screen_body.dart`)**
- Drop `DriverRideFlowScaffold` **centered modal card + back title** → **bottom-fixed offer sheet** over live framed map (coords from ride — no Amsterdam default).
- **Fare largest element**; metrics row demoted below fare, not equal weight.
- Decline: **top-right text pill**, not second full-width button (Accept stays sole bottom CTA; Skip moves to corner).
- Map: **required** — route line + leg badges (data fix + UI).

**Logic unchanged:** countdown from invite `expires_at`, `acceptRide` / `declineRide` RPCs, `accept_ride_error_message.dart`.

---

### §3 En route to pickup

**Bolt:** navigation dominates; **Route details** is an **expandable sheet** (fare, destination, Cancel, Contact, Waze, Stop new requests).

**HeyCaby redesign — NAV-FIRST + expandable peek**

```
┌──────────────────────────────────────────────┐
│  FULL MAP / external nav hint (Waze launched) │
│  [Open Waze]              [Route details ⌃]  │
│  ╭─────────────────────────────────────────╮ │
│  │ ─── handle                               │ │
│  │  En route to pickup · €18.00             │ │
│  │  Zwartendijk 11, Monster                 │ │  ← destination preview
│  │  ┌──────── Cancel order ────────┐        │ │
│  │  ┌──────── Contact rider ──────┐        │ │
│  │  ┌──────── Waze · Change ──────┐        │ │
│  │  ┌──────── Stop new requests ──┐        │ │
│  ╰─────────────────────────────────────────╯ │
╰──────────────────────────────────────────────┘
```

**Collapsed peek (default while driving):** `Pickup · 12 min` + rider name + **Open navigation** accent button only.

**Expanded:** full Route details list (Bolt §3 parity).

**Changes vs today (`driver_navigation_focus_body.dart`)**
- Replace tall `DriverRidePhaseHero` + scroll card with **thin bottom sheet**.
- Wire **fare** into sheet header (`expectedAmountLabel` — already partially there).
- `Stop new requests` on this sheet **and** at-pickup and in-progress (gap from driver map doc).

**Logic unchanged:** `DriverNavigationLauncher`, `driver_cancel_ride_flow.dart`, communication sheet.

---

### §4 Chat

**Bolt:** header with rider + address; auto-translate banner; lavender quick-reply chips; camera in composer.

**HeyCaby redesign**

```
┌──────────────────────────────────────────────┐
│  ✕   Mădălina · pickup address        📞      │  ← no masked call (product rule)
│  ───────────────────────────────────────────  │
│  [ Auto-translate info banner ]  (future)     │
│  👋  I'm here  On my way  Send location       │  ← move pings INTO chat as chips
│  ───────────────────────────────────────────  │
│  messages…                                    │
│  [📷]  Type a message              [send]     │
╰──────────────────────────────────────────────┘
```

**UI-only phase 1:** chips inside `driver_chat_screen.dart`; banner styling with `colors.accentL`. Translation/photo = phase 2 (backend).

**Logic unchanged:** `messages` table, `driver_rider_conversation_body.dart`.

---

### §5 Arrived / Waiting

**Bolt:** map `Wait here`; **`01:15 Waiting`** hero; fare tick-up; green **Start trip**.

**HeyCaby redesign — FIXED sheet, waiting timer as hero**

```
┌──────────────────────────────────────────────┐
│  MAP: car at pickup, "Wait here" label        │
│  ╭─────────────────────────────────────────╮ │
│  │     01:15 Waiting                        │ │  ← live timer (existing service)
│  │     €20.00  (+€2.00 wait)                │ │  ← displayFare = base + wait
│  │  Pickup address                          │ │
│  │  Rider · 5.0 ★                           │ │
│  │  ┌─────────────────────────────────┐    │ │
│  │  │       Start trip                 │    │ │  accent
│  │  └─────────────────────────────────┘    │ │
│  │  [Chat]  [Waive fee]                     │ │  secondary row
│  ╰─────────────────────────────────────────╯ │
╰──────────────────────────────────────────────┘
```

**Changes vs today (`driver_pickup_arrival_body.dart`, `at_pickup_screen.dart`)**
- Timer **larger than address** (invert current hierarchy).
- Show **total fare rising**, not only “fee added so far.”
- Single primary CTA; waive + chat as **icon row**, not competing buttons.

**Logic unchanged:** `markArrived`, `fn_driver_waive_waiting_fee`, waiting timer service.

---

### §6 Break — “Need a break?”

**Bolt:** centered modal over dimmed map; confirm copy; Start break / Cancel.

**HeyCaby redesign**

- Replace length-picker-only flow with **Bolt copy modal** first: *“After your current ride you won't receive new requests.”*
- Then optional duration picker as **second step**.
- Use standard `AlertDialog` / bottom sheet with `DriverButton` — `driver_shift_timer_widget.dart` logic unchanged; add `pendingBreak` deferral (state-only).

---

### §7 Safety toolkit

**Bolt:** shield on map → sheet: Emergency call (red), Share trip, Audio record.

**HeyCaby redesign**

- **Shield FAB** on all trip sheets (`driver_map_floating.dart`) — not only Driver Hub.
- Sheet mirrors Bolt order:
  1. **Emergency (112)** — `colors.error`, `tel:112` + audit log (existing hub code)
  2. **Share trip details** — `getOrCreateRideShareUrl`
  3. **Audio recording** — row present; wire when ready
- Reuse `DriverHubSafetySection` rows inside a **ride overlay sheet**.

---

### §8 Trip in progress

**Bolt:** big map + ETA; red **End trip**; Route details with Add stop (HeyCaby: no add-stop at launch — hide row until backend).

```
┌──────────────────────────────────────────────┐
│  NAV / map to destination                     │
│  ╭─────────────────────────────────────────╮ │
│  │  18 min · Destination address            │ │
│  │  €18.00                                  │ │
│  │  ┌─────────────────────────────────┐    │ │
│  │  │       End trip                   │    │ │  **destructive** red
│  │  └─────────────────────────────────┘    │ │
│  │  Route details · Safety · Chat            │ │
│  ╰─────────────────────────────────────────╯ │
╰──────────────────────────────────────────────┘
```

**Changes vs today**
- `End trip` → `DriverButtonVariant.destructive` (one-line enum).
- Collapsed peek = ETA + fare + End trip only; expand for route/contact/cancel.

**Logic unchanged:** `completeRide` RPC, navigation launcher.

---

### §9 Complete → Rate rider

**Bolt:** rate screen → back online fast.

**HeyCaby redesign**

- **Fixed bottom sheet** or half-screen modal: 1–5 stars + optional tags + submit.
- On submit: dismiss to **home map online**, not an extra “complete” page.
- Keep `rate_rider_screen.dart` route but **restyle** as sheet content component.

---

### §10–§12 History, Balance, Rating (tabs)

**Bolt:** filter chips, payment icon per row, balance explainer modal, star breakdown.

**HeyCaby redesign (lists only — stay full screen)**

| Screen | Bolt detail to mimic | HeyCaby file |
|---|---|---|
| Rides history | Finished filter, payment icon on row | `driver_my_rides_screen.dart`, `DriverLedgerHistoryItem` |
| Balance | Negative balance warning + explainer modal | `driver_platform_balance_body.dart` |
| Star rating | Histogram + liked tags | `driver_score_screen.dart` |

Use **same sheet typography** (handle, section titles) inside these pages for family resemblance.

**Logic unchanged:** finance RPCs, 0% commission model (no Bolt −€60 cutoff).

---

## 3. Modal inventory (driver A→Z)

| Moment | Container | Fixed / Expandable | Primary CTA |
|---|---|---|---|
| Idle home | Expandable peek | Expand | Go offline |
| Go-online blockers | Fixed sheet | Fixed | Fix & retry |
| Incoming offer | Fixed ~55% | Fixed | Accept |
| En route | Expandable | Expand | Open navigation |
| Route details | Expandable full | Expand | Stop new requests |
| Chat | Full overlay | Fixed | Send |
| Arrived | Fixed | Fixed | Start trip |
| Break confirm | Center modal | Fixed | Start break |
| Safety | Fixed sheet | Fixed | Emergency |
| In progress | Expandable | Expand | End trip (destructive) |
| Rate rider | Fixed / half | Fixed | Submit |
| Cancel ride | Fixed + illustration | Fixed | Wait / Cancel |

---

## 4. What NOT to copy (business stays HeyCaby)

| Bolt | HeyCaby |
|---|---|
| Cash-debt balance / −€60 cutoff | Weekly platform balance, Mollie, `driver_platform_fee_gate` |
| Bolt commission per trip | 0% commission |
| Masked phone in chat | Chat + pings only |
| Add stop / change destination (until backend) | Hide or grey out |
| Bolt “Offers/quests” strip | Optional later; don’t fake |
| Orange “Go offline” | Use `warning` or outline — keep **accent** for positive actions only |

---

## 5. Implementation phases (UI-only, no logic rewrites)

### Phase 1 — Ride loop feels Bolt (highest ROI)
1. Offer sheet: bottom-fixed, fare hero, map route, corner Decline.
2. End trip → destructive red.
3. Waiting: timer + rising fare hero.
4. Safety shield on trip map → hub safety sheet.
5. Route details expandable sheet (fare in header).

### Phase 2 — Home & polish
6. Home peek collapse + floating today earnings chip.
7. Chat quick-reply chips inside composer.
8. Break confirm modal + deferred break hint.
9. Rate rider as dismissible sheet.

### Phase 3 — Tab screens
10. History payment icons + filter chips.
11. Rating histogram + tags display.
12. Localize `Accept` via `_t` (remove hardcoded `Accepteren`).

---

## 6. Acceptance checklist (Bolt driver on HeyCaby)

A Bolt driver should answer **yes** within 3 seconds on each screen:

| Question | After redesign |
|---|---|
| Where do I go offline? | Home peek, one button |
| What do I earn on this job? | € hero on offer + route sheet |
| Accept or decline? | Green bottom Accept; small Decline top-right |
| How do I navigate? | Obvious Open Waze / nav button on peek |
| I'm at pickup — what now? | Big waiting timer → Start trip |
| How do I end the ride? | Red End trip |
| Emergency? | Shield → 112 |
| Where's my money today? | Top earnings chip on map |

---

## 7. Wireframe summary (one glance)

```text
HOME          OFFER         EN ROUTE        ARRIVED         IN TRIP
[map]         [map+route]   [map+nav]       [map wait]      [map+nav]
[earn chip]   [fixed sheet] [peek sheet]    [fixed sheet]   [peek sheet]
[peek sheet]  € + Accept    Route details⌃  01:15 Wait      End trip RED
```

---

## 8. Relation to existing docs

- **Behavior source of truth:** `StepByStep-Driverflow-Map.md` (Bolt reference + gap analysis).
- **Rider modal pattern:** rider Bolt screenshots — fixed vs expandable sheets; driver ride loop should mirror the same **map + sheet** language for cross-app consistency.
- **This doc:** **how** to reskin HeyCaby driver UI to match Bolt placement and hierarchy using **existing** `DriverColors`, `DriverButton`, `DriverRideFlowScaffold` (evolved), and current providers.

---

*Next step when ready for implementation: Phase 1 in `driver_ride_flow_common.dart` + `driver_opportunity_screen_body.dart` without changing router paths or RPC calls.*
