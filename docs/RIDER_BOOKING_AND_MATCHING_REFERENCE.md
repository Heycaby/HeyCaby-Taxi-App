# Rider booking & driver matching — end-to-end reference

This document is the **product and flow reference** for implementing the rider journey from address entry through payment, request dispatch, driver matching, and in-trip communication. It incorporates the **proximity-first category cards**, **expandable per-driver detail**, and **cascading driver invites** (closest-first batches, atomic assignment).

### How to implement against this repo (not from scratch)

- **Evolve what exists**: HeyCaby already has Rider/Driver Flutter apps, shared packages, and Supabase-backed flows. Treat this document as a **target shape**; **modify** current screens, providers, and APIs in **small, reviewable steps**—do **not** replace the booking stack wholesale.
- **Do not break the codebase**: Preserve current behavior where the spec does not require a change; gate new matching or UI behind clear steps (e.g. feature flag or incremental rollout) if needed; run **`flutter analyze`** and relevant tests on touched app paths after changes.
- **Follow project rules**: Match existing file layout, naming, and patterns (`rider-flow-implementation`, `rider-theme-language`, `rider-file-structure` skills). **No hard-coded colors**—theme and tokens only. Avoid drive-by refactors and unrelated file edits; every change should trace to this flow or a stated bugfix.
- **Backend parity**: When changing rider or driver behavior, keep **contracts** (tables, RPCs, Realtime) consistent so both apps and the database stay in sync.

---

## 1. Design principles (UI)

- **Visual hierarchy**: Category-level cards are the primary surface. **Category name** and **available count** (e.g. **5**) must read as **first-class, bold emphasis**—scannable from a distance. **Distance** (e.g. nearest ~10 km) and **price** (e.g. **from €20**) are secondary/tertiary per layout, but always legible.
- **Expandable cards**: Collapsed row = category summary (count, headline distance, “from” price). **Tap** expands to **individual vehicles/drivers** with **their** distance and **their** price (not averaged into the headline without labeling).
- **Honest copy**: Headline row uses **estimates** where needed; expanded rows are **per-offer** truth. Avoid bait-and-switch between collapsed and expanded states.
- **Theming**: **No hard-coded colors.** Use platform and app **design tokens** only (e.g. Material `ColorScheme`, shared theme extensions, typography scales) so light/dark and brand stay consistent.
- **Accessibility**: Sufficient contrast via theme, scalable type, clear touch targets for expand/collapse and primary actions.

---

## 2. Matching model (backend behavior)

**Goal**: User chooses a **category** (e.g. Standard); the system finds drivers in that category near pickup, but does not spam every driver at once.

### 2.1 Cascading invites (recommended)

1. When the rider **confirms** the request for a category, create a **single open ride / request** record (source of truth).
2. Select the **closest N** eligible drivers (e.g. 3–5), excluding **stale GPS** (location older than agreed threshold).
3. Notify that batch; each gets a **time window** (T seconds) to accept.
4. **First accept wins** via an **atomic** transition (e.g. only one driver can flip the request from `open` → `assigned`; others receive “already taken”).
5. If no acceptance in the window, **expand to the next ring** (next nearest batch) and repeat until timeout or cancellation.

**Why**: Preserves “closest first” **perception** and **fairness**, reduces notification fatigue, and scales better than broadcasting to all drivers in the category at once.

### 2.2 Stale GPS and eligibility

- Only drivers who are **online**, **available**, match **vehicle category** (and any capability flags, e.g. wheelchair), and have **fresh location** participate in ordering and invites.

### 2.3 Relationship to the UI

- The **card list** can still show **all categories** and **counts** from a **radius query** (or cached snapshot + realtime updates).
- The **cascade** applies at **“Send request”** for the **selected category**, not necessarily to every name on the expanded list simultaneously.

---

## 3. End-to-end flow (start → finish)

Phases below are **sequential** unless noted. Use this as the checklist when wiring navigation, state, and APIs.

### Phase A — Entry & pickup

1. Rider opens booking / map experience.
2. Rider sets **pickup** (search, map pin, or current location with permission).
3. System validates pickup (service area, precision, address resolution).
4. Optional: show map centered on pickup; persist pickup coordinates + display label.

### Phase B — Drop-off

5. Rider enters **drop-off** (search or map).
6. System resolves route **pickup → drop-off** (polyline, distance, duration estimates).
7. Show **route preview** on map and **high-level ETA / distance** for the trip (not yet per-category if pricing differs by category).

### Phase C — Category & supply (proximity cards)

8. Backend (or client + API) loads **live supply** near pickup: per **vehicle category**, **count**, **nearest distance**, **headline “from” price** (estimate), optional **ETA to pickup** for nearest.
9. Rider sees **sleek category cards** with clear hierarchy (category + **bold count**, distance, from-price).
10. Rider **expands** a card to see **individual** options (per driver/vehicle: distance, price, any badges).
11. Rider **collapses** or switches category as needed; list may **refresh** on timer or realtime events (drivers move, go offline).

### Phase D — Payment method

12. Rider selects **payment** (e.g. card on file, wallet, cash—per product policy).
13. Validate method is usable for this trip (e.g. card valid, region allowed).

### Phase E — Summary & confirmation

14. **Summary screen**: pickup, drop-off, route snapshot, **chosen category** (not necessarily one specific driver until assigned), payment method, **price estimate** (and any fees/surge explained).
15. Legal / policy acknowledgements if required (terms, cancellation policy).
16. Primary CTA: **Send request** (or “Request ride”)—creates the server-side request and starts matching.

### Phase F — Dispatch & driver matching

17. Server creates **open request** tied to rider, route, category, payment context.
18. **Cascade** runs: notify batch 1 (closest N); wait; atomic accept or next batch.
19. Rider UI: **searching / matching** state (timer, cancel option, optional “widening search” copy if batches expand).

### Phase G — Driver assigned

20. On success, request becomes **assigned** to one driver; rider sees **driver profile** (name, vehicle, plate, rating), **ETA to pickup**, and **contact/chat** entry points.
21. Driver app shows **job accepted**, full trip details, navigation to pickup.

### Phase H — Chat & special information

22. **Chat** (or structured quick messages) opens between rider and driver after assignment (or per policy when allowed).
23. **Driver** can send status messages (e.g. **“On my way”**, **“Arrived”**—some may be **system-assisted** buttons tied to trip state).
24. **Rider** can send **special instructions** (e.g. gate code, luggage, child seat, meeting point)—persisted in thread and/or trip notes for support and safety policies.
25. Moderation / safety: report/block flows if already in product scope.

### Phase I — Pickup → on trip → completion

26. Driver marks **arrived at pickup** (or geofence-assisted); rider is prompted **“I’m outside”** / verify vehicle.
27. Trip starts (**on trip**); show live route to destination, updated ETA.
28. Trip ends; **fare confirmation**, **receipt**, **tip** (if applicable), **rating**.
29. Post-trip: history, support, rebook.

### Phase J — Failure paths (reference)

- **No drivers** in category after cascade exhaustion: clear message, suggest other category, retry, or schedule.
- **Rider cancels** while matching: stop cascade, notify pending drivers “cancelled.”
- **Driver cancels** after accept: re-open request or re-run cascade (policy-dependent).
- **Payment failure** after assign: defined fallback (retry, different method, cancel).

---

## 4. Sync: rider app, driver app, backend

| Concern | Backend | Rider | Driver |
|--------|---------|-------|--------|
| Pickup/drop-off, route | Stores canonical trip request; route snapshot | Sends addresses/coords | N/A until assigned |
| Supply / counts / cards | Geospatial + eligibility queries; optional realtime | Subscribes/polls for card data | Pushes location + online state |
| Matching | Cascade logic, atomic accept, timeouts | Matching UI | Notification → accept/decline |
| Trip state | Single state machine | UI per state | UI per state |
| Chat / extras | Messages + trip metadata | Send/receive | Send/receive |

**Single source of truth**: trip/request ID and state on the server; clients reflect subscriptions or polling with optimistic UI only where safe.

---

## 5. Naming & file role

- **File**: `docs/RIDER_BOOKING_AND_MATCHING_REFERENCE.md`
- **Use**: Product/engineering reference when implementing screens, APIs, Realtime channels, and driver notification logic. Update this doc when flows change (e.g. new payment type or new trip state).

---

## 6. Related repo docs

- `docs/TECHNICAL_DOCUMENTATION.md` — monorepo and architecture overview.
- Rider implementation skill / flow docs under `.cursor/skills/` (booking flow, theme/language) — align UI tokens and navigation with those conventions.

---

## 7. What this repo implements (A → Z contract)

This section ties the **reference** above to **shipping code** in this monorepo.

| Capability | Implementation |
|------------|----------------|
| Category + supply UI + real `drivers.vehicle_category` | Rider `vehicle_category_screen` + `nearby_supply_service.dart` (bbox query on `driver_locations`, then `drivers` lookup). |
| Persist rider choices on the request | `ride_request_provider.dart` inserts `vehicle_category`, `pet_friendly`, `booking_mode`. |
| Cascading invites (closest batches, expiry, next ring) | Supabase migration `supabase/migrations/20260329180000_ride_matching_cascade.sql`: `ride_request_invites`, `fn_seed_ride_matching_batch`, trigger on `ride_requests` insert, rider timer on `searching_screen.dart`. |
| First accept wins (atomic) | RPC `fn_driver_accept_ride_invite` + `DriverApi.acceptRide` (Supabase RPC first, HTTP `/api/driver/ride/accept` fallback if RPC unavailable). |
| Driver notified | `RideInviteRealtimeListener` on `ride_request_invites` INSERT when driver is online. |

**You must:** apply the migration to your Supabase project, turn on **Realtime** for `public.ride_request_invites`, set each driver’s `vehicle_category` / `accepts_pets` as needed, and ensure `ride_requests` / RLS allow the trigger and RPCs to run. The HTTP accept fallback remains for environments where the new RPC is not deployed yet.
