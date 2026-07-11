# Taxi Terug™ Blueprint

**Status:** ✅ **Approved** — living blueprint, **dev-ready** (safeguards below are mandatory for V1)  
**Owner:** Product / CTO  
**Last updated:** 2026-07-08  
**Related:** [HEYCABY_BACKEND_FLOW_BLUEPRINT.md](./HEYCABY_BACKEND_FLOW_BLUEPRINT.md) · [PRODUCT-PRINCIPLES.md](./PRODUCT-PRINCIPLES.md) · [RIDER_BOOKING_AND_MATCHING_REFERENCE.md](./RIDER_BOOKING_AND_MATCHING_REFERENCE.md)

> **How to use this doc**  
> This is the product blueprint for **Taxi Terug™** — not a full rebuild spec. Backend reuse is intentional where it already works. Add ideas under [Brainstorm log](#brainstorm-log); promote to main sections when agreed.

---

## Table of contents

1. [CTO vision](#cto-vision)
2. [Product definition](#product-definition)
3. [Canonical example (Ahmed & David)](#canonical-example-ahmed--david)
4. [What Taxi Terug is — and is not](#what-taxi-terug-is--and-is-not)
5. [Golden rule](#golden-rule)
6. [Product language](#product-language)
7. [Driver experience (target)](#driver-experience-target)
8. [Rider experience (target)](#rider-experience-target)
9. [Algorithm & match scoring](#algorithm--match-scoring)
10. [Booking & next-ride queue](#booking--next-ride-queue)
11. [Dispatch flow](#dispatch-flow)
12. [Privacy rules](#privacy-rules)
13. [Pricing principles](#pricing-principles)
14. [Badge rules](#badge-rules)
15. [Benefits](#benefits)
16. [Backend objects](#backend-objects)
17. [What already exists (inventory)](#what-already-exists-inventory)
18. [Safeguards & trust rules (mandatory)](#safeguards--trust-rules-mandatory)
19. [Gap analysis](#gap-analysis)
20. [V1 scope & acceptance criteria](#v1-scope--acceptance-criteria)
21. [App Store & marketing copy](#app-store--marketing-copy)
22. [Known bugs & trust issues](#known-bugs--trust-issues)
23. [Open questions](#open-questions)
24. [Brainstorm log](#brainstorm-log)
25. [Changelog](#changelog)
26. [Quick reference](#quick-reference)

---

## CTO vision

### One-line product

**Taxi Terug should become a smart return-trip marketplace that matches riders with taxis already heading their way.**

### Taglines

| Audience | Line |
|----------|------|
| **Driver** | Never drive home empty again. |
| **Rider** | Ride with taxis already heading your way. |

### CTO decision

**Build as an intelligent return-trip system — not a fake label.**

Reuse existing backend where it works:

- Return Mode (`fn_driver_return_mode_*`)
- Home zone / `home_city` / destination lat-lng
- Directional matching (`fn_terugtaxi_qualify`)
- Return discount (`active_return_discount_pct`)
- Driver tariffs
- Existing dispatch + invite waves

**Elevate into branded product:** **🚖 Taxi Terug™**

### Strategic differentiation

| Uber / Bolt | HeyCaby Taxi Terug |
|-------------|-------------------|
| Optimize **nearest** driver | Optimize **driver intent** + empty-km reduction |
| Generic dispatch | Signature return-trip marketplace |

### CTO verdict (final)

**Approved as living blueprint.** Before implementation, the [10 mandatory safeguards](#safeguards--trust-rules-mandatory) below are part of the contract — especially:

- Driver consent (no silent supply)
- Rider waiting tolerance
- Queued state (`reserved_for_next_ride` / `queued_taxi_terug`)
- Current-ride priority (no interference)

### Product story

> *"I was going home anyway… now I'm getting paid for it."*

---

## Product definition

**Taxi Terug means:**

> A rider books a taxi that is **already travelling toward their destination**.

| | Taxi Terug | Not this |
|--|------------|----------|
| Mechanism | Empty-kilometre matching | Normal nearest-driver dispatch |
| Rider UX | Book a taxi already going your way | Marketplace bidding war |
| Vehicle | Independent taxi, own route | Shared taxi / pooling |
| Pricing | Driver-set tariff (+ optional return discount) | Platform-forced discounts |

**The driver was already going that way. The rider fills the empty return journey.**

---

## Canonical example (Ahmed & David)

1. **Ahmed** lives in Amsterdam. He drives a rider **Amsterdam → Rotterdam**.
2. After drop-off, Ahmed needs to return to Amsterdam.
3. **David** wants **Rotterdam → Amsterdam**.
4. Taxi Terug shows David:

   ```
   Taxi heading to Amsterdam
   Available in 45 min
   [ Book this return taxi ]
   ```

5. David books Ahmed.
6. Ahmed completes his current ride, then receives:

   ```
   Taxi Terug booked
   Next rider is going to Amsterdam
   ```

7. Ahmed picks up David and earns on the way home instead of driving empty.

**That is the product.**

*(Same pattern as Oud-Beijerland → Eindhoven with terugrit toward Rotterdam — see [Brainstorm log](#brainstorm-log).)*

---

## What Taxi Terug is — and is not

Taxi Terug is a **smart matching system** connecting:

- **Drivers** already travelling in a direction (or about to)
- **Riders** travelling in the **same direction**

**Nobody:**

- changes their destination
- shares rides (pooling)
- gets platform-imposed pricing

The platform **removes empty kilometers**.

---

## Golden rule

> **Taxi Terug is only valid if it reduces empty kilometres.**

If it does not reduce empty kilometres, it is a **normal ride**.

- Amsterdam → Rotterdam while heading Amsterdam → Rotterdam: ✅  
- Amsterdam → Almere while heading Amsterdam: ❌  
- Oud-Beijerland → Spijkenisse (local): ❌  

---

## Product language

### Brand name

**Taxi Terug** — not TerugTaxi, Return Mode, Retourmodus, Trip Radar, or Marktplaats (in terug flow).

> *"Ik neem een Taxi Terug."*

### Driver mental model

| ❌ Don't say | ✅ Say |
|-------------|--------|
| Activate Return Mode | **Naar huis** / **Taxi Terug activeren** |
| Deadhead | **Naar ophaalpunt** |
| Trip (paid) | **Rit** / **Rit naar {bestemming}** |
| Retourmodus | **Taxi Terug** |
| Marketplace | **Taxi Terug** (rider) |

### Driver question we answer

> *"Can you help me earn money on the way home?"*

---

## Driver experience (target)

### Driver home data (required)

Every driver should have:

| Field | Purpose |
|-------|---------|
| `home_zone` / `heading_home_zone_id` | Zone-based fallback |
| `home_city` | Label fallback |
| `home_lat` / `home_lng` | Direction + distance math |
| *(via return mode)* `return_mode_destination_*` | Active Taxi Terug destination |

**Today:** `home_city`, `heading_home_zone_id`, and return mode destination fields exist on `drivers`. Explicit `home_lat`/`home_lng` on driver profile — verify schema; return mode stores destination lat/lng on activate.

### When Taxi Terug becomes relevant

**Example rule:**

```
IF driver is more than 20 km from home
AND (driver is online OR finishing a ride)
AND driver has no next ride queued
THEN suggest Taxi Terug
```

Do not ask too many questions. Show:

```
Heading back to Amsterdam?
We can find riders going your way.
[ Activate Taxi Terug ]
```

One tap.

### Automatic smart activation (suggest only — never silent)

Suggest Taxi Terug when **all** apply:

- [x] Driver is away from home zone (e.g. > 20 km — configurable via `suggest_home_distance_km`)
- [x] Driver just completed a ride **or** is near completing one (post-ride prompt + in-transit supply)
- [x] Driver has home zone / destination configured
- [x] Driver is eligible (`fn_driver_can_accept_rides`, active tariff)
- [x] Fresh GPS (qualify + dispatch gates)
- [x] Driver is not on break (dispatch eligibility)
- [x] No next ride already queued (queue + restore guards)

**Never activate without driver consent.** Show smart prompt → driver taps once.

> **Staging smoke still required** — two-device end-to-end proof before production.

### Post-ride fork

```
What would you like to do next?

🏠 Naar huis      → Taxi Terug
🚕 Doorwerken    → Go online
☕ Pauze          → Go offline
```

### Taxi Terug activation screen

```
Taxi Terug
Bestemming: Amsterdam
Ophaalradius: 10 km

[ Taxi Terug activeren ]
```

Advanced: return discount % on manage screen only.

### Driver dashboard (home card)

```
Taxi Terug
Richting Amsterdam
67 km te gaan
3 mogelijke ritten in de buurt
```

### Driver consent on inbound Taxi Terug booking (V1)

**V1 decision (explicit): manual accept only. No auto-accept.**

| Version | Auto-accept |
|---------|-------------|
| **V1** | ❌ **Off — manual accept only** |
| Later | Optional after trust + testing (`return_mode_auto_accept_enabled` — column exists, **not implemented in V1**) |

Manual confirmation UI:

```
Taxi Terug request
David is going to Amsterdam
Pickup 6 min from your drop-off

[ Accept Taxi Terug ]    [ Skip ]
```

### Driver supply consent (mandatory — no silent participation)

A driver **only appears in Taxi Terug supply** if they have **explicitly opted in**:

- Activated Taxi Terug (`return_mode_enabled = true`), **or**
- Accepted a Taxi Terug prompt / inbound offer in-session

**Rules:**

- Riders **cannot** book a driver who is finishing a current ride unless that driver has **enabled Taxi Terug** or **accepted** a Taxi Terug offer.
- **No silent participation** — being online or on a ride is not enough.
- Backend candidate RPC must gate on `return_mode_enabled` (already in `fn_terugtaxi_qualify`); UI must not show in-transit drivers without opt-in.

### Opportunity card (incoming ride)

Smart templates — not deadhead jargon. Badge only when ride **qualifies** (see [Algorithm](#algorithm--match-scoring)).

### Stats (v2)

```
Taxi Terug — deze maand
312 km bespaard
€486 verdiend aan terugritten
```

---

## Rider experience (target)

### Entry

Home: **🚖 Taxi Terug**  
Tagline: *Ride with taxis already heading your way.*

### Rider Taxi Terug browse (target UI)

```
Taxi Terug to Amsterdam
3 taxis heading your way

Ahmed
Arrives near you in 45 min
Black Tesla Model Y
Estimated fare €35–€50
[ Book Taxi Terug ]
```

### Delayed pickup explanation (required copy)

```
This taxi is already heading your way.
The driver is finishing a nearby ride first.
Pickup available in 45–50 min
```

**NL draft:**

```
Deze taxi rijdt al jouw kant op.
De chauffeur rondt eerst een rit in de buurt af.
Ophaal beschikbaar over 45–50 min
```

### Rider waiting tolerance (mandatory)

Taxi Terug often means **delayed pickup**. Riders must see honest timing **before** booking — and optionally declare how long they can wait (later enhancement).

**V1 (required):**

- Show range: **Pickup available in 45–50 min** (from timing rule + buffer)
- Rider confirms they understand delayed pickup before booking

**V1.1+ (optional UI):**

```
I can wait up to:
[ 15 min ]  [ 30 min ]  [ 60 min ]
```

**Why:** Prevents book-then-cancel when the taxi is still finishing another ride. Filter or rank candidates where `estimated_available_at` exceeds rider tolerance.

### Psychological goal

Rider thinks: *"I'm getting a taxi that was already coming this way."*  
Not: *"I'm using a complicated marketplace."*

---

## Algorithm & match scoring

### Algorithm goal

> **Is this driver already going where this rider wants to go?**

- **Yes** → show Taxi Terug  
- **No** → do not show it  

### Match score (0–100) — target V1

Only show drivers with **score > 70**.

| Factor | Weight | Question |
|--------|--------|----------|
| **Direction match** | 40% | Does rider destination move driver closer to home/return destination? |
| **Pickup fit** | 20% | Is pickup near driver's drop-off or return corridor? |
| **Destination fit** | 20% | Is rider destination near driver home/return destination? |
| **Timing fit** | 10% | Can driver reach rider at reasonable time? |
| **Driver quality** | 10% | Rating, acceptance history, etc. (TBD) |

**V1 formula:**

```
score =
  direction_score × 40
+ pickup_score      × 20
+ destination_score × 20
+ timing_score      × 10
+ driver_quality    × 10
```

Also require hard gates: **vehicle fit**, **payment fit**, **tariff fit** (valid tariff → price range visible).

### Direction rule

A ride qualifies when:

```
distance(driver_position, driver_home)
>
distance(rider_destination, driver_home)
```

Rider's destination **brings the driver closer to home**.

**Example:** Driver in Rotterdam, home Amsterdam, rider destination Amsterdam → qualifies.

**Maps to existing backend:** `fn_terugtaxi_qualify` uses `progress_km` and `progress_ratio` (min 3 km, min 8% toward home). **Align UI threshold with score > 70.**

### Corridor rule

Draw a corridor: **driver current/drop-off → driver home**.

Taxi Terug pickup/destination should be **inside or near** that corridor.

| Corridor Rotterdam → Amsterdam | Good | Bad |
|-------------------------------|------|-----|
| Stops on route | Delft, Den Haag, Leiden, Schiphol, Amsterdam | Breda, Zeeland, Almere, Arnhem |

**Gap:** corridor geometry not in current SQL — qualify uses point-to-home progress only. **Phase 2+** enhancement.

### Pickup rule

Rider pickup must not force driver too far off route.

```
pickup within 5–15 km of driver route (configurable)
```

**Maps to existing:** `pickup_radius_km` / `pickup_distance_max_km` in qualify + config default 10 km.

### Timing rule

If driver is on an active ride:

```
estimated_available_at =
  current_ride_eta_to_dropoff
+ handover_buffer   (e.g. 5 min)
```

Rider sees: **Available in 50 min**

**Gap:** `fn_rider_taxi_terug_supply` does not expose per-driver `estimated_available_at` or in-transit state today.

### Vehicle, payment, tariff fit

| Gate | Source |
|------|--------|
| Vehicle (Taxi / TaxiBus / Wheelchair) | `fn_dispatch_driver_eligible` |
| Payment methods | Same |
| Valid tariff | Driver readiness / rate profile |

---

## Booking & next-ride queue

### Target flow

```
Rider books Taxi Terug
        ↓
Backend creates next-ride queue entry
        ↓
Driver notified (manual accept V1)
        ↓
Current ride continues  ← current rider always has priority
        ↓
After drop-off / payment
        ↓
Taxi Terug ride activates
        ↓
Driver navigates to next pickup
```

**Driver is reserved as next ride — not active until current ride completes.**

### Queued state (mandatory — Missing 5)

Clear state between **current ride** and **next Taxi Terug ride**. Prevents driver appearing "available" while still finishing another passenger.

**Proposed states** (pick one naming convention in implementation):

| State | Meaning |
|-------|---------|
| `reserved_for_next_ride` | Driver has accepted terug booking; still on current ride |
| `queued_taxi_terug` | Same — explicit Taxi Terug queue semantics |

**Driver app:** show *"Taxi Terug geboekt — volgende rit na afronding"*  
**Rider app:** show assigned driver + *"Pickup available in …"*  
**Dispatch:** driver must **not** receive conflicting instant dispatch as "available" while in this state.

### Current-ride priority (mandatory — Missing 4)

**Taxi Terug must never interfere with the current passenger.**

| Rule | Implementation |
|------|----------------|
| Current rider always has priority | No terug UI that delays active navigation or payment |
| No distracting terug prompts mid-ride | Driver terug accept sheet only when safe (parked / post-phase) — product decision per screen |
| Terug offers do not change current ride ETA | Timing uses `estimated_available_at` after drop-off, not during active leg |
| No rider PII in terug preview | See [Privacy rules](#privacy-rules) |

### Driver cancellation protection (mandatory — Missing 3)

If driver accepts Taxi Terug, then cancels before pickup:

| Action | Required |
|--------|----------|
| Rider notified | Immediately — push + in-app |
| Ride returns to search | Re-enter Taxi Terug candidate pool / matching |
| Audit log | Write event (driver_id, ride_id, reason, timestamp) |
| Repeat offenders | Temporary hide from Taxi Terug supply after N cancellations (configurable threshold) |

Use `driver_return_mode_events` or dedicated `taxi_terug_audit` events — extend, do not replace existing audit patterns.

### Backend

- Use existing `ride_requests` with `booking_mode = 'terug'` (internal; UI = Taxi Terug)
- **Next Ride Queue system** — **gap:** no dedicated terug queue contract documented in migrations; shift handover has queued-ride pattern (`shift_handover_queued`) — **reuse or extend, Phase 3–4**
- Add **`queued_taxi_terug` / `reserved_for_next_ride`** status field or `dispatch_state` flag — **required before Phase 4 go-live**

---

## Dispatch flow

```text
DRIVER ACTIVATES TAXI TERUG
────────────────────────────
Driver away from home
    → taps Activate Taxi Terug
    → backend stores destination = home zone
    → driver enters Taxi Terug candidate pool

RIDER SEARCHES TAXI TERUG
─────────────────────────
Rider enters destination
    → backend finds drivers heading that way
    → score candidates (score > 70)
    → show best candidates

RIDER BOOKS
───────────
Rider chooses driver
    → backend re-verifies eligibility (fn_terugtaxi_qualify)
    → creates queued ride
    → notifies driver + rider

DRIVER ACCEPTS
──────────────
Driver accepts Taxi Terug
    → ride reserved
    → rider sees assigned driver
    → driver completes current ride
    → Taxi Terug becomes active
```

---

## Privacy rules

### Never show (current passenger privacy)

- Current rider name
- Current rider exact pickup/drop-off
- Current rider private trip details
- Full live route before booking if privacy-sensitive

### Allowed before booking

- Driver first name
- Vehicle make/model
- Plate **after** booking confirmed
- Estimated availability time
- Return destination (e.g. "Heading to Amsterdam")
- Approximate route corridor
- "Driver is finishing a nearby ride"

### Rider-facing safe copy

```
Driver is finishing a nearby ride
Available in 45 min
Heading to Amsterdam
```

---

## Pricing principles

- **Drivers set the price** — HeyCaby does not force discounts.
- Show **estimated fare range:** `€35–€50`
- Subline: *Prices are set by independent taxi drivers already travelling your way.*

### Fare explanation (mandatory — protects brand)

**Taxi Terug does not mean cheap by default.**

> Taxi Terug means the taxi is **already going your direction**. Price still depends on the **driver's tariff**.

Show in rider flow (NL draft):

> *Taxi Terug betekent dat de taxi al jouw kant op rijdt. De prijs hangt af van het tarief van de chauffeur.*

**Do not** promise automatic discounts. **Do not** say "discount marketplace" or "bidding."

**Soft value line (OK):**

> Often better value because the taxi is already travelling your way.

**If driver configured return discount — show honestly:**

> Taxi Terug price includes 15% return discount.

**Do not invent discounts. Do not advertise "50% cheaper."**

---

## Badge rules

**Badge belongs to the ride — not the driver.**

Do **not** show Taxi Terug badge because driver has Taxi Terug on.

Show **only** when **this specific ride qualifies** (qualify / score > 70).

| Route | Badge? |
|-------|--------|
| Amsterdam → Rotterdam (heading home) | ✅ |
| Amsterdam → Almere | ❌ |
| Oud-Beijerland → Spijkenisse | ❌ |

---

## Benefits

### Driver

- Earn on return journeys
- Less empty driving
- Better long-distance efficiency
- More predictable work
- Strong reason to use HeyCaby

### Rider

- Taxis already going their direction
- Often better value / pickup timing for inter-city
- More sustainable (shared empty-km reduction)
- Strong for city-to-city rides

### HeyCaby

- **Signature product** — hard for nearest-driver apps to copy
- Optimizes **intent**, not just proximity

---

## Backend objects

### Reuse (existing)

**Driver intent** — `drivers` return mode contract:

| Field | Status |
|-------|--------|
| `return_mode_enabled` | ✅ |
| `return_mode_destination_lat/lng/label` | ✅ |
| `return_mode_destination_zone_id` | ✅ |
| `pickup_distance_max_km` | ✅ |
| `active_return_discount_pct` | ✅ |
| `return_mode_auto_accept_enabled` | ⚠️ stub |
| `expires_at` | ❌ not on contract |
| `destination_type` | ❌ not explicit |

**Matching today:**

| RPC | Returns today | Target |
|-----|---------------|--------|
| `fn_terugtaxi_qualify` | qualify yes/no + metrics | Use for badge + booking gate |
| `fn_rider_taxi_terug_supply` | supply **count** | Extend or add candidates RPC |
| `fn_seed_taxi_terug_matching_batch` | invite seeding | Keep for wave dispatch |

### Add when missing (proposed)

**`fn_rider_taxi_terug_candidates`** (or extend supply RPC):

```sql
fn_rider_taxi_terug_candidates(
  pickup_lat, pickup_lng,
  destination_lat, destination_lng,
  vehicle_type, payment_methods
)
```

**Returns per candidate:**

| Field | Purpose |
|-------|---------|
| `driver_id` | Booking target |
| `driver_name` | First name only |
| `vehicle` | Make/model |
| `estimated_available_at` | Timing rule |
| `pickup_eta_minutes` | After available |
| `estimated_fare_min` / `max` | From tariff |
| `match_score` | 0–100 |
| `why_match` | Human explanation for UI |

**Booking:** `ride_requests` + `booking_mode = 'terug'` + next-ride queue (TBD).

### Admin / support visibility (mandatory — Missing 7)

Ops must debug: *"Why was this marked Taxi Terug?"*

Persist and expose (admin/support tooling — not rider-facing):

| Debug field | Source |
|-------------|--------|
| `match_score` | Scoring function |
| `progress_km` | `fn_terugtaxi_qualify` |
| `progress_ratio` | qualify |
| `pickup_detour_km` | pickup vs corridor |
| `destination_fit` | destination score component |
| `timing_fit` | ETA / availability score |
| `reason_shown_to_rider` | `why_match` copy snapshot |

Store on qualify event (`driver_return_mode_events` payload JSON) and/or `ride_requests.dispatch_state` terug metadata.

### Anti-abuse: fake Taxi Terug destinations (mandatory — Missing 8)

Drivers must not game the system with fake "home" destinations to capture more terug rides.

| Control | Rule |
|---------|------|
| Destination cooldown | Min time between destination changes (e.g. 4–24 h — config) |
| Max changes per day | Cap activations / destination edits (e.g. 2–3/day) |
| Audit logs | Every activate / destination change → `driver_return_mode_events` |
| Suspicious patterns | Rapid destination flips flagged for ops review; optional temporary suspend from terug supply |

---

## Safeguards & trust rules (mandatory)

**All 10 items below are required before V1 ship.** Cross-reference implementation phases.

| # | Safeguard | Section |
|---|-----------|---------|
| 1 | **Driver supply consent** — no silent participation; only `return_mode_enabled` or accepted prompt | [Driver consent](#driver-supply-consent-mandatory--no-silent-participation) |
| 2 | **Rider waiting tolerance** — show 45–50 min; optional wait cap later | [Rider waiting tolerance](#rider-waiting-tolerance-mandatory) |
| 3 | **Driver cancellation protection** — notify rider, re-search, audit, repeat-offender hide | [Driver cancellation](#driver-cancellation-protection-mandatory--missing-3) |
| 4 | **Current-ride priority** — terug never interferes with active passenger | [Current-ride priority](#current-ride-priority-mandatory--missing-4) |
| 5 | **Queued state** — `reserved_for_next_ride` / `queued_taxi_terug` | [Queued state](#queued-state-mandatory--missing-5) |
| 6 | **Fare explanation** — direction ≠ cheap by default | [Fare explanation](#fare-explanation-mandatory--protects-brand) |
| 7 | **Admin/debug fields** — match score, progress, why_match | [Admin visibility](#admin--support-visibility-mandatory--missing-7) |
| 8 | **Anti-fake destination** — cooldown, max changes, audit, flags | [Anti-abuse](#anti-abuse-fake-taxi-terug-destinations-mandatory--missing-8) |
| 9 | **V1 = manual accept only** — no auto-accept | [V1 scope](#v1-scope-explicit) |
| 10 | **App Store copy** — no discount marketplace / bidding language | [App Store copy](#app-store--marketing-copy) |

---

## What already exists (inventory)

### Backend

| Asset | Location | vs algorithm vision |
|-------|----------|---------------------|
| `fn_terugtaxi_qualify` | `20260708194500_...` | ✅ Direction + pickup radius; ❌ no score 0–100, no corridor |
| `fn_rider_taxi_terug_supply` | same | ⚠️ Count only, not candidate cards |
| `fn_seed_taxi_terug_matching_batch` | same | ✅ Scores drivers for **invites** (different formula) |
| Return mode RPCs | `20260630133609_...` | ✅ Intent storage |
| `terugtaxi_config` | app_config | ⚠️ `enabled: false` default |
| Seed scoring | terug batch | `100 − pickup×3 + progress×1.5` — **align with 40/20/20/10/10** |

### Driver app

| Surface | State |
|---------|-------|
| Return mode provider + RPCs | ✅ |
| Home card ("Retourmodus") | ⚠️ rename + km remaining |
| Post-ride prompt | ⚠️ binary, no 20 km rule |
| Opportunity badge | ❌ driver toggle, not qualify |
| Return trips browser | ✅ separate from live candidates |

### Rider app

| Surface | State |
|---------|-------|
| Home Taxi Terug tile | ✅ |
| Marketplace bid flow | ⚠️ not candidate browse |
| `fn_rider_taxi_terug_supply` | ❌ unwired |
| In-transit book driver | ❌ not built |
| Privacy-safe copy | ❌ |

---

## Gap analysis

### Summary matrix (updated)

| Vision pillar | Built? | Gap | Phase |
|---------------|--------|-----|-------|
| Direction rule (progress toward home) | ✅ | Wired to UI badge | 1 |
| Match score 0–100, threshold 70 | ✅ | `fn_taxi_terug_match_score` | 2 |
| Corridor rule | ❌ | Geo enhancement | 2+ |
| `fn_rider_taxi_terug_candidates` | ✅ | RPC + rider browse UI | 2 |
| Rider candidate cards (Ahmed UI) | ✅ | Marketplace terug section | 2 |
| In-transit book + ETA | ✅ | Timing rule + queue | 3–4 |
| Next ride queue for terug | ✅ | `queued_taxi_terug` | 4 |
| Driver manual accept terug booking | ✅ | Invite + next-ride badge | 3 |
| 20 km from home suggest rule | ✅ | `suggest_taxi_terug` in return mode status | 2 |
| Privacy rules enforced in API | ✅ | Candidate RPC filters fields | 2 |
| Badge = ride qualifies | ✅ | `fn_terugtaxi_qualify` only | 1 |
| Taxi Terug branding | ✅ | Copy pass done | 1 |
| Stats dashboard | ✅ | `fn_driver_taxi_terug_stats` + home card (V1 km = trip distance proxy) | 5 |
| Feature enabled | ✅ | Staging `terugtaxi_config.enabled` | 1 |
| Driver supply consent gate | ✅ | Candidates RPC + qualify | 1–2 |
| Rider wait tolerance UI | ✅ | Chips + delayed-pickup ack | 3 |
| Driver cancel → re-search | ✅ | `fn_taxi_terug_handle_driver_cancel` | 3 |
| Queued state | ✅ | `queued_taxi_terug` status | 4 |
| Current-ride non-interference | ✅ | Queue + non-urgent invites | 3 |
| Admin debug payload | ✅ | match_score / why_match on qualify + candidates | 2 |
| Anti-fake destination | ✅ | Cooldown + daily cap RPC | 2 |
| V1 manual accept only | ✅ | No auto-accept RPC | 1 |
| Function ACL lockdown | ✅ | `20260708270000_taxi_terug_function_lockdown` | post-5 |
| Direct candidate book (no bid) | ⚠️ | Browse cards exist; underlying flow still marketplace bid | post-V1 |

### Critical code bugs (Phase 1) — fixed

~~Badge tied to `return_mode_enabled`~~ — fixed in Phase 1 (`taxi_terug_qualified` from `fn_terugtaxi_qualify` only).

~~`return_mode_active` stamped on every offer~~ — removed in Phase 1.

---

## V1 scope & acceptance criteria

### V1 scope (explicit)

| In V1 | Not in V1 |
|-------|-----------|
| Manual driver accept for Taxi Terug bookings | **Auto-accept** (defer until trust + testing) |
| Driver must opt in to appear in supply | Silent / automatic supply inclusion |
| Badge + supply gated by qualify | Badge on driver toggle |
| Honest delayed-pickup copy | Hidden ETA |
| All [10 safeguards](#safeguards--trust-rules-mandatory) | Corridor geometry (optional Phase 2+) |
| `booking_mode = 'terug'` internal | Renaming DB enum (UI only = Taxi Terug) |

### Build plan (CTO — aligned with inventory)

| Phase | Scope |
|-------|--------|
| **1** ✅ | Rename UI to **Taxi Terug**; badge = qualify only; enable `terugtaxi_config` on staging; deadhead jargon; **V1 manual accept**; driver supply consent gate; fare explanation copy |
| **2** ✅ | `fn_rider_taxi_terug_candidates`; rider browse; 20 km suggest; privacy; **admin debug fields**; **anti-fake destination** controls |
| **3** ✅ | Book driver finishing ride; accept/skip UX; **rider wait tolerance** display; **current-ride non-interference**; **driver cancel protection** |
| **4** ✅ | **`queued_taxi_terug` state** + next-ride queue until current completes |
| **5** ✅ | Empty-km saved + earnings dashboard |

### Acceptance criteria — Taxi Terug is real when:

**Core flow**

1. [x] Driver has home zone / destination configured  
2. [x] Driver is away from home  
3. [x] Driver activates Taxi Terug (one tap, **explicit consent**)  
4. [x] Rider opens Taxi Terug  
5. [x] Rider sees **only** opt-in drivers heading toward destination (score > 70)  
6. [~] Rider can book a specific driver — browse cards yes; direct book without bid flow still post-V1  
7. [x] Driver is notified — **manual accept in V1**  
8. [x] Rider sees **Pickup available in X–Y min** before confirming  
9. [x] Driver completes current ride without terug interference  
10. [x] Taxi Terug ride activates from **queued** state  
11. [x] **No** private current-rider data leaks  
12. [x] Badge appears **only** on real Taxi Terug matches  

**Safeguards (mandatory)**

13. [x] Driver **not** in supply without `return_mode_enabled` or accepted terug opt-in  
14. [x] Rider shown delayed-pickup expectation before book  
15. [x] Driver cancel before pickup → rider notified + re-search + audit  
16. [x] `queued_taxi_terug` / `reserved_for_next_ride` state visible to driver + rider  
17. [x] Fare copy: direction ≠ cheap by default  
18. [x] Admin can inspect match_score, progress_km, why_match  
19. [x] Destination change cooldown + daily cap enforced  
20. [x] **No auto-accept** in V1  

**Production gate (remaining)**

- [ ] Two-device staging smoke (driver online + Return Mode → rider Terug → queued accept → complete → activate)
- [x] TAXI TERUG function ACL lockdown (`REVOKE PUBLIC`; internal helpers `service_role` only)

---

## App Store & marketing copy

### Use

> **Taxi Terug** connects riders with taxis already heading their way.

**NL:**

> **Taxi Terug** verbindt passagiers met taxi's die al jouw richting op rijden.

### Do not use

- "Discount marketplace"
- "Bidding" / "bieden"
- "50% cheaper" / "altijd goedkoper"
- "Return Mode" / "Retourmodus" (user-facing)
- "Shared rides"

### Driver App Store angle

> Never drive home empty again.

### Rider App Store angle

> Ride with taxis already heading your way.

---

## Known bugs & trust issues

| Issue | Symptom | Root cause |
|-------|---------|------------|
| Badge always on | TAXI TERUG on local 10 km ride | Badge tied to `return_mode_enabled` |
| Marktplaats bleed | Rider sees Marktplaats after Terug tile | Shared marketplace screens |
| Feature off | No terug matches in QA | `terugtaxi_config.enabled: false` |
| Bidding ≠ browse | Rider names price, doesn't pick Ahmed | Current terug = marketplace bid flow, not candidate book |

---

## Open questions

1. **20 km from home** — confirm threshold; store in `terugtaxi_config`?  
2. **Match score** — implement in SQL or map qualify output to 0–100 in app?  
3. **Next ride queue** — new table or extend `ride_requests` status?  
4. **`home_lat`/`home_lng`** on driver profile vs return mode destination only?  
5. **Corridor rule** — Phase 2 or defer?  
6. **Enable staging config** — who flips `terugtaxi_config.enabled`?  
7. **booking_mode** — keep internal `'terug'`; UI always "Taxi Terug"? ✅ yes  
8. **Destination cooldown hours** — default 4h, 12h, or 24h?  
9. **Max destination changes per day** — 2 or 3?  
10. **Driver cancel threshold** — hide from terug after N cancels in 7 days?  

---

## Brainstorm log

### 2026-07-08 — Initial blueprint

- Product not toggle; badge on qualification; Dutch copy; backend reuse.

### 2026-07-08 — Gold mine / algorithm vision (CTO)

- **Product:** smart return-trip marketplace — empty-km matching, not dispatch, not bidding, not pooling.  
- **Canonical story:** Ahmed Amsterdam↔Rotterdam, David books return taxi, 45 min availability.  
- **20 km from home** suggest rule; never silent activation.  
- **Match score** 40/20/20/10/10, show only > 70.  
- **Corridor rule** Rotterdam→Amsterdam (Delft/Leiden good; Breda/Almere bad).  
- **Timing:** `estimated_available_at` = ride ETA + buffer.  
- **Next ride queue** for in-transit booking — Phase 4.  
- **Privacy:** first name + vehicle only before book; no current passenger PII.  
- **V1 manual accept**; auto-accept later.  
- **fn_rider_taxi_terug_candidates** proposed.  
- **12 acceptance criteria** added.  
- **HeyCaby differentiation:** intent vs nearest driver.

### 2026-07-08 — Final safeguards (CTO approval)

- **Approved** for dev with 10 mandatory safeguards (consent, wait tolerance, cancel protection, current-ride priority, queued state, fare explanation, admin debug, anti-abuse, V1 manual-only, App Store copy).
- V1 explicitly **no auto-accept**.

### Ideas parking lot

- [ ] Push: *"Taxi Terug geboekt — volgende passagier naar Amsterdam"*  
- [ ] Rider map: taxis on corridor (approximate, privacy-safe)  
- [ ] FAQ: Wat is Taxi Terug? (driver + rider)  
- [ ] Align seed batch scoring with public match score formula  
- [ ] Rider wait tolerance filter: hide drivers where `available_at > rider_max_wait`

---

## Changelog

| Date | Change |
|------|--------|
| 2026-07-08 | Initial blueprint |
| 2026-07-08 | Algorithm vision: Ahmed/David, match scoring, corridor/timing, dispatch flow, 5-phase plan |
| 2026-07-08 | **Phase 1 shipped (app):** qualify badge, Taxi Terug strings, rider terug copy, staging config already enabled |
| 2026-07-08 | **Phase 2 shipped:** `fn_rider_taxi_terug_candidates`, match score on qualify, rider candidate browse UI, 20 km suggest prompt, destination change guards |
| 2026-07-08 | **Phase 3 shipped:** in-transit drivers in supply, wait tolerance filter, queued accept while finishing ride, delayed-pickup UX, driver cancel audit + supply hide |
| 2026-07-08 | **Phase 4 shipped:** queue status RPCs, driver in-ride banner, rider active-ride queued copy, dispatch guard for queued drivers, restore picks non-queued ride first |
| 2026-07-08 | **Phase 5 shipped:** empty-km saved on terug complete, `fn_driver_taxi_terug_stats`, driver home stats card |
| 2026-07-09 | **Production hardening:** `20260708270000_taxi_terug_function_lockdown` — REVOKE PUBLIC on all terug RPCs; internal helpers service_role-only |
| 2026-07-09 | Blueprint checklist + gap matrix synced to implementation; driver qualify test import fixed |

---

## Quick reference

### RPCs (today)

```
fn_driver_return_mode_status | activate | disable | dismiss_prompt | prompt_shown
fn_taxi_terug_config
fn_terugtaxi_qualify              ← direction + pickup gates + match_score
fn_rider_taxi_terug_supply        ← count only
fn_rider_taxi_terug_candidates    ← privacy-safe browse cards (+ in-transit, wait filter)
fn_rider_taxi_terug_queue_status  ← rider queued pickup window
fn_driver_taxi_terug_queue_status ← driver next-ride queue
fn_driver_taxi_terug_stats        ← km saved + earnings (V1: km = trip distance proxy)
fn_seed_taxi_terug_matching_batch
fn_seed_ride_matching_batch       (router)
-- internal (service_role only after lockdown):
fn_taxi_terug_queue_accepted_invite | activate_queued_ride | handle_driver_cancel | record_completion
```

### Proposed (Phase 3+)

### Key migrations

- `supabase/migrations/20260630133609_driver_return_mode_contract.sql`
- `supabase/migrations/20260708194500_taxi_terug_booking_mode.sql`

### Key app files

| App | Files |
|-----|-------|
| Driver | `driver_home_sheet.dart`, `ride_complete_screen.dart`, `driver_opportunity_bolt_layout.dart`, `new_ride_request_screen.dart` |
| Rider | `home_booking_options_grid.dart`, `marketplace_screen.dart`, `booking_provider.dart`, `ride_request_provider.dart` |
