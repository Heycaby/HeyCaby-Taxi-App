# Step-by-Step Rider Flow Map — Bolt (Reference Analysis, mirrored from the Driver Flow)

> **Purpose.** This is the **rider-side companion** to `StepByStep-Driverflow-Map.md`. Where the driver doc was reconstructed from real on-road screenshots, this doc is **inferred by mirroring the driver flow**: every action the driver takes is a *reaction* to a **signal the rider sent**, and every driver state has a matching **thing the rider sees**. Mapping both sides against each other lets us confirm the two HeyCaby apps are **in sync** — that for every A→Z step in a ride, the screen the rider needs exists and lines up with the driver screen it drives.
>
> **The core inversion.** *The rider sends the signal; the driver reacts.* The driver's "Ride offer" (driver §2) only exists because the rider **composed and sent a request**. The driver's "Arrived" state only exists because the rider is being told "your driver is here." So each section below states, explicitly: **① what the rider composes/sends**, **② what the rider sees while the driver acts**, and **③ which driver-doc section it maps to**.
>
> Scope: **rider side only** — from opening the app and setting a destination, through requesting, matching, tracking the driver in, riding, paying, and finally rating and history.
>
> **We are not changing HeyCaby's flow.** This maps the ideal A→Z so we can verify every screen exists and find the gaps — not to re-architect the journey.

---

## 0. The Flow at a Glance (rider side)

```text
                        ┌─────────────────────────────────────────────┐
                        │        HOME / SET DESTINATION                │  ← sees nearby supply
                        │  map · "Where to?" · saved places · supply   │
                        └───────────────────────┬─────────────────────┘
                                                 │ pick pickup + destination
                                                 ▼
                        ┌─────────────────────────────────────────────┐
                        │   COMPOSE THE RIDE (this becomes the offer)  │
                        │  category · fare estimate · payment · prefs  │
                        └───────────────────────┬─────────────────────┘
                                                 │ Find my driver  ── SIGNAL ──▶ (driver §2 Offer)
                                                 ▼
        ┌───────────────┐   no driver   ┌──────────────────────────┐
        │ Notify me /   │◀─────────────│    SEARCHING FOR DRIVER    │
        │ Schedule /    │               │  radar · wave · cancel     │
        │ Marketplace   │               └───────────┬──────────────┘
        └───────────────┘                           │ a driver ACCEPTS (driver §2 → §3)
                                                     ▼
                                ┌────────────────────────────────────┐
                     chat ◀────▶│  DRIVER FOUND · live track to you   │  (mirrors driver §3 en route)
                (translate)     │  driver card · car · plate · ETA    │
                                └───────────────────┬────────────────┘
                                                    │ driver ARRIVES (driver §5)
                                ┌───────────────────▼──────────────────┐
   Share trip / SOS ◀──────────│   DRIVER ARRIVED · waiting meter      │
                                │   "Your driver is outside" · fee      │
                                └───────────────────┬──────────────────┘
                                                    │ driver taps Start trip (driver §8)
                                ┌───────────────────▼──────────────────┐
   Share trip / SOS ◀──────────│        TRIP IN PROGRESS               │
                                │        live track · ETA to dest       │
                                └───────────────────┬──────────────────┘
                                                    │ driver taps End trip (driver §9)
                                                    ▼
                        ┌─────────────────────────────────────────────┐
                        │  TRIP COMPLETE → pay → rate driver (+ tip)   │
                        └───────────────────────┬─────────────────────┘
                                                 ▼
        ┌───────────────┐   ┌──────────────────┐   ┌──────────────────────┐
        │  Ride history │   │ Payment methods  │   │  Your rider rating    │
        │  + receipts   │   │  / wallet        │   │  (drivers rate you)   │
        └───────────────┘   └──────────────────┘   └──────────────────────┘
```

**Design principle (rider mirror of the driver's "one primary action" rule):** at every state the rider also has exactly **one primary action** — `Where to?` → `Find my driver` → (wait) → `Track / Chat` → `Pay` → `Rate`. Everything else (share, cancel, report, safety) is a **sheet/modal over the map**, so the rider always knows the single next thing to do. The rider's buttons carry the *opposite* intent of the driver's: the rider **requests and waits**, the driver **accepts and drives**.

---

## 1. Home / Set Destination — the rider's idle screen

**Maps to driver §1 (Online/Idle Home).** The driver sits idle watching *demand*; the rider sits on Home watching *supply*. Same map, inverted concern.

**① What the rider composes/sends:** nothing binding yet — this is where the rider seeds **pickup** (auto from GPS) and taps into **"Where to?"**.

**② What the rider sees:**
- **Live map** centered on their location with a **center pickup pin**.
- A **"Where to?" hero card** — the single entry point into the booking flow.
- **Nearby driver supply** — the rider equivalent of the driver's demand heatmap. Instead of "where are the riders," the rider sees **"are there cars near me right now"** (a count / per-category availability). This is the rider's confidence signal that a request will get picked up.
- Shortcuts: saved places (Home/Work), recent destinations, favourites, airport, scheduled.

**Why it's built this way:** the driver's idle job is "where do I sit to get pinged." The rider's idle job is the mirror — "**can I get a car, and where am I going.**" Both are answered in one glance (map + supply + one CTA). Supply visibility is to the rider what the heatmap is to the driver: it sets expectations *before* a request is sent, reducing dead-end searches.

---

## 2. Compose the Ride — this is what becomes the driver's Offer

**Maps to driver §2 (Ride Offer).** Everything the driver evaluates in ~5 seconds — fare, vehicle tier, pickup/dropoff, distance — is **assembled here by the rider**. This is the single most important sync point between the two apps: **the rider's compose screen is the driver's offer card, one signal apart.**

**① What the rider composes/sends (each field lands on the driver's offer):**
- **Pickup + destination** → become the driver's two-leg route (`16 min • 17.1 km` to pickup, `12 min • 8.3 km` trip).
- **Vehicle category** (standard / comfort / taxibus / wheelchair) → the driver's **product/tier tag**.
- **Fare estimate** shown to the rider → the driver's **€ fare** headline (they must agree — the number the rider is quoted is the number that justifies the driver's accept).
- **Payment method** (cash / card / Tikkie) → the driver's **payment chip**.
- **Preferences:** pet-friendly, favourites-first / favourites-only, pickup contact name → dispatch targeting + info the driver sees.
- **Now vs scheduled** → instant dispatch vs a future pickup.

**② What the rider sees:** per-category **fare estimates** and **nearby availability** for each tier, so the choice is informed before committing.

**Why it's built this way:** the driver decides in 5 seconds because the rider **already made all the decisions here**. Any field missing on this screen is a field missing (or defaulted) on the driver's offer — that's why parity matters. The rider's "estimate" and the driver's "fare" must come from the **same pricing source**, or the two sides disagree at the worst moment (accept).

---

## 3. Request Sent → Searching for a Driver

**Maps to the moment between driver §1 and §2 — the dispatch itself.** When the rider taps **Find my driver**, the request is created and **broadcast to drivers** (this *is* the offer the driver receives). The rider now waits.

**① What the rider sends:** the ride request (`status: pending`) — the actual signal. Re-seeding/expanding waves keep re-broadcasting to more drivers over time.

**② What the rider sees:**
- **Radar / searching screen** — animated "finding your driver," an elapsed/remaining clock, rotating "did you know" cards to fill dead time.
- **Dispatch progress** — which wave the search is on, how many drivers were notified, closest car / ETA. This is the rider's view of the driver-side dispatch fan-out.
- **Cancel** — the rider can abandon the search (this is the "rider cancelled" signal the driver/dispatch must honour).

**Why it's built this way:** waiting is the rider's highest-anxiety moment (mirror of the driver's "is this fare worth it"). Showing **live dispatch progress** ("notifying nearby drivers… 3 drivers pinged") converts silent waiting into visible effort, which is what keeps the rider from cancelling prematurely. The search window must stay open long enough for **late-joining drivers** (a driver coming online mid-search) to be pulled in — the rider should never have to rebook just because they searched a few seconds too early.

---

## 4. No Driver Found — Notify me / Schedule / Marketplace

**Maps to driver §2 timeout / decline.** When no driver accepts (all declined or none online), the rider needs a graceful off-ramp — the mirror of a driver's offer expiring.

**① What the rider sends:** a fallback choice — "**notify me** when a driver is free" (a background standing search), "**schedule** for later," or "**try the marketplace**" (open the request to driver bids).

**② What the rider sees:** a **"no driver right now" sheet** offering exactly those three actions plus "try again," and — if they chose notify-me — a **persistent background-search card / live activity / push** so they can leave the app and be pinged when supply appears.

**Why it's built this way:** a failed search must never be a dead end. Bolt-class flows always convert "no car" into a **scheduled or notified** intent so demand isn't lost. This is the rider mirror of "declining is safe" — **failing to match is safe**, because the app immediately offers a path forward instead of dumping the rider back to an empty Home.

---

## 5. Driver Found / Assigned — live-track the driver to you

**Maps to driver §3 (En route to pickup).** The driver accepted and is now navigating **to the rider**. Everything the driver does on their Route-details sheet, the rider watches happen.

**① What the rider sends:** nothing required — but chat and cancel remain available.

**② What the rider sees:**
- **"Driver found" / "Driver on the way"** state with a **driver card**: name, photo, **car make/model/colour/plate**, and **driver rating**. (The plate is the rider's mirror of the driver's "send photo of your location" — it's how they identify each other.)
- **Live driver location on the map** moving toward pickup, with an **ETA to pickup** that updates.
- **Status progression** the rider is walked through: searching → **driver assigned** → arriving → arrived → in progress → completed, driven by realtime + push.

**Why it's built this way:** this is the payoff for the wait. The driver card answers "**who/what am I looking for**," the moving marker answers "**how long till they're here**," and the live status answers "**what's happening right now.**" It mirrors the driver's Route-details sheet exactly: the driver sees the rider's pin and address; the rider sees the driver's car and ETA — two views of the same converging line.

---

## 6. Communicating with the Driver — In-app Chat

**Maps to driver §4 (Chat).** Same channel, opposite end. Used mostly at the last 100 metres ("I'm at the blue door," "2 min away").

**① What the rider sends:** text, and ideally **one-tap canned messages** ("I'm coming down," "which car?", "please wait 1 min"), so they don't type while walking out.

**② What the rider sees:** the driver's messages, ideally **auto-translated** into the rider's language (the driver doc's "Translated automatically → On my way" works both ways).

**Why it's built this way:** the language barrier and "don't make them type" problems are symmetric. The driver shouldn't type while driving; the rider shouldn't type while juggling bags at the kerb. Canned chips + two-way translation solve both. Chat is gated to the active-ride window on both sides so it opens exactly when it's useful and closes when the ride ends.

---

## 7. Driver Arrived + Waiting — the rider's side of the meter

**Maps to driver §5 (Arrived & Waiting).** The driver tapped nothing yet except "I'm here"; the waiting meter is running. The rider is the party the meter is holding accountable.

**① What the rider sends:** ideally a quick ping ("coming now") to stop the clock socially.

**② What the rider sees:**
- **"Your driver has arrived / is outside."**
- A **waiting card** showing the **free grace time remaining**, then the **accruing waiting fee** and rate — the rider's view of the exact fare bump the driver sees tick up (€18 → €20 in the driver doc). Plus the **waiver** state if the driver waives it.

**Why it's built this way:** the driver doc monetises waiting **in the driver's favour and makes it visible**. For fairness, the **rider must see the same meter** — otherwise the fee is a nasty surprise on the receipt. Transparency on both screens is what makes the waiting fee defensible: the rider was warned, in real time, with a running number.

---

## 8. Safety & Sharing — always one tap over the map

**Maps to driver §7 (Safety toolkit).** Both parties get a safety layer; the rider's is centred on **share + emergency + report**.

**① What the rider sends:** a **share-trip link** (live status + location to a trusted contact), an **emergency escalation** (112), or a **report**.

**② What the rider sees:** a **safety sheet** reachable from the active-ride screen (share trip, emergency, report/support), mirroring the driver's fixed shield.

**Why it's built this way:** safety is a two-sided trust feature. The driver can share their trip and call authorities; the rider must have the identical escalation (share → report → emergency). It's always reachable over the map during the ride, never buried — same rule as the driver side.

---

## 9. Trip In Progress — riding to the destination

**Maps to driver §8 (Trip in progress).** The driver drives with a big map and a red **End trip**; the rider rides and watches.

**② What the rider sees:** **"On the way"** with the **destination ETA**, the **live position** on the map, and share/safety still one tap away. The fare shown should reflect any waiting already added.

**Why it's built this way:** during the paid leg the rider's only real question is "**when do I arrive**," so ETA-to-destination dominates. Everything money-affecting has already been decided; the rider view stays calm and informational, mirroring the driver's "navigation dominance, one CTA" principle — except the rider's single job is simply *to arrive*, so there's no CTA competing with the map.

---

## 10. Trip Complete → Pay → Rate the Driver (+ Tip)

**Maps to driver §9 (Complete → rate rider → back online).** The driver taps End trip; the fare finalises; **both sides rate each other.**

**① What the rider sends:** **payment** (or confirmation, for cash), a **1–5★ rating** with tags/comment, and optionally a **tip**.

**② What the rider sees:** a **fare summary / receipt** (base + waiting + total + method) and the **rating screen**, then back to Home.

**Why it's built this way:** mutual rating is the backbone of the marketplace — the rider rates the driver in the same beat the driver rates the rider, while it's fresh. The receipt closes the money loop transparently. Tip is the rider's optional "thank you" lever that the driver sees in earnings.

---

## 11. Ride History + Receipts

**Maps to driver §10 (Rides history).** The driver reconciles payouts; the rider reconciles spend.

**② What the rider sees:** a dated list of past trips (route, date, fare, status), each drilling into a **full receipt / fare breakdown**, plus upcoming/scheduled rides.

**Why it's built this way:** the rider needs to **verify what they paid** and re-book easily ("ride again"). Filters by status/date make it fast; each row opens the same receipt the driver's history opens from their side — one trip, two ledgers.

---

## 12. Payment Methods / Wallet

**Maps to driver §11 (Earnings & Balance).** For the driver this screen is *money in*; for the rider it's *money out* — how they pay.

**② What the rider sees / manages:** their **payment methods** (cash / card / Tikkie, and ideally a saved-card wallet with a default), used to prefill the compose step (§2).

**Why it's built this way:** the driver's balance screen answers "what am I owed"; the rider's payment screen answers "how do I pay." They're the two ends of the same transaction. A managed wallet here makes §2 a one-tap payment choice instead of re-deciding every ride.

---

## 13. Rider Reputation — your own passenger rating

**Maps to driver §12 (Star rating).** Drivers are rated by riders (driver §12); symmetrically, **riders are rated by drivers** — so the rider should be able to see their own passenger score.

**② What the rider sees:** their **passenger rating** (e.g. ★ 4.9), ideally with the same "what drivers liked" framing.

**Why it's built this way:** a two-sided marketplace rates both sides. Showing the rider their own score nudges good behaviour (be on time, be respectful) exactly the way the driver's score nudges theirs. It's the mirror of driver §12.

---

## 14. Scheduled / Upcoming Rides + Airport (rider-specific)

**Maps loosely to the driver's scheduled-rides surface.** This is where the rider manages **future** rides rather than the live one.

**② What the rider sees / manages:** an **upcoming rides** list with detail + **cancel/edit**, a **scheduled-ride queued** confirmation, an **airport booking** shortcut, and the **notify-me background search** state.

**Why it's built this way:** not every ride is "now." Scheduling and airport flows capture high-intent future demand; the notify-me search captures demand that couldn't match instantly. Both keep the rider in the funnel between rides — the rider mirror of keeping a driver productive between fares.

---

## 15. State Machine Summary (rider side, for implementation)

| # | Rider state | Rider sees | Primary CTA | Signal sent to driver/dispatch | Maps to driver § | Exit condition |
|---|-------------|------------|-------------|-------------------------------|------------------|----------------|
| 1 | **Home/Idle** | map, nearby supply, "Where to?" | `Where to?` | — | §1 | destination chosen → §2 |
| 2 | **Compose ride** | category, fare estimate, payment, prefs | `Find my driver` | request payload (= the offer) | §2 | confirm → §3 |
| 3 | **Searching** | radar, dispatch wave, ETA | `Cancel` | `pending` ride broadcast | §2 (dispatch) | driver accepts → §5 / timeout → §4 |
| 4 | **No driver** | notify/schedule/marketplace sheet | `Notify me` / `Schedule` | standing search / scheduled intent | §2 timeout | driver appears → §5 |
| 5 | **Driver found** | driver card, car, plate, live ETA | `Track` / `Chat` | — (watching) | §3 | driver arrives → §7 |
| 6 | **Chat** (overlay) | messages, translate, canned replies | send | chat message | §4 | back to current state |
| 7 | **Arrived/Waiting** | "driver outside," waiting meter+fee | `Chat` / ping | ping "coming" | §5 | driver starts trip → §9 |
| 8 | **Safety** (sheet) | share trip, emergency, report | Share / Emergency | share link / SOS | §7 | returns to ride |
| 9 | **Trip in progress** | ETA to destination, live map | (none / share) | — (riding) | §8 | driver ends trip → §10 |
| 10 | **Complete/Pay/Rate** | fare summary, rate driver, tip | submit rating | payment + rating (+tip) | §9 | → Home |
| A | **Ride history** | past trips + receipts | (row → receipt) | — | §10 | — |
| B | **Payment methods** | cash/card/Tikkie, wallet | add/set default | — | §11 | — |
| C | **Rider rating** | own passenger score | — | — | §12 | — |
| D | **Upcoming/Scheduled** | future rides, airport, notify-me | view/cancel/edit | scheduled/standing request | (scheduled) | pickup time → §3 |

---

## 16. Cross-cutting Design Rules (rider lens — mirrors of the driver's 8 rules)

1. **One primary action per state.** `Where to?` → `Find my driver` → `Track/Chat` → `Pay` → `Rate`. One large CTA at a time; never two competing.
2. **Money is visible and honest — the same number on both sides.** The rider's **estimate at compose** must equal the driver's **fare on the offer**, the **waiting meter** the rider sees must equal the driver's rising fare, and the **receipt** must match. Any divergence between the two apps is a trust bug.
3. **Failing to match is safe.** No driver → immediate notify/schedule/marketplace off-ramp, never a dead end (mirror of "declining is safe").
4. **Don't make the rider type.** Canned chat chips + auto-translation at the kerb, mirroring the driver's anti-typing rule.
5. **Modals for everything non-riding.** Chat, safety, share, cancel, receipt are sheets over the map; the map + next action never disappear.
6. **State advances on the driver's explicit tap, and the rider is told immediately.** The rider never guesses — every driver tap (accept, arrive, start, end) pushes a realtime/notification status change to the rider in the same second.
7. **Safety is first-class for the rider too.** Share-trip + emergency + report always one tap from the active ride.
8. **Close the loop fast.** Complete → pay → rate → Home → "ride again," so the rider's path back to the next booking is near-zero friction.

---

## 17. HeyCaby Rider Gap Analysis — Where We Stand vs This Bolt Flow

> **Same ground rule as the driver doc: do NOT change the app's aesthetics.** HeyCaby's rider app already has the screens, theme, sheets and colour tokens. Closing a gap means **wiring behaviour / data / one reused component into the existing UI** — not restyling. Where a Bolt feature conflicts with HeyCaby's model, it's flagged as an **intentional divergence**, not a gap.
>
> Audit basis: full read of `apps/rider/lib` + `packages/`. Status legend: **✅ Present** · **🟡 Partial** · **🔴 Missing** · **⚪ Intentional divergence**.

### 17.1 Scorecard (whole rider flow at a glance)

| Flow phase (this doc §) | Capability | Status | Where it lives today |
|---|---|---|---|
| §1 Home | Live rider-centered map + "Where to?" | ✅ | `home_screen.dart`, `home_search_hero_card.dart` |
| §1 Home | **Nearby driver supply on Home** | 🟡 | aggregate count only (`NearbySupplyService.probeDriverCount`); per-category lives on vehicle screen |
| §1 Home | Saved places / recents / airport shortcuts | ✅ | `home_recent_places_section.dart`, `home_popular_airports_section.dart` |
| §2 Compose | Address search (pickup+dest, swap) | ✅ | `search_screen.dart`, `address_search_modal.dart` |
| §2 Compose | Vehicle category picker | 🟡 | `vehicle_category_screen.dart` — **comfort hidden** (`_visibleCategories` = standard/taxibus/wheelchair) |
| §2 Compose | Pet-friendly toggle | ✅ | `vehicle_category_screen.dart` |
| §2 Compose | Favourites-first toggle | ✅ | `vehicle_category_screen.dart` (`favoritesFirst`) |
| §2 Compose | **Favourites-only toggle (instant)** | 🟡 | only on marketplace scope picker, not instant vehicle screen |
| §2 Compose | **Per-category fare estimate** | 🟡 | live supply-rate band used; `tripCategoryEstimatesProvider` built but **unused** |
| §2 Compose | Payment method choice | ✅ | `payment_screen.dart` (cash / pin / Tikkie) |
| §2 Compose | Pickup contact name | 🟡 | captured on payment screen, not vehicle screen |
| §2 Compose | Trip summary + "Find my driver" + save-for-later | ✅ | `trip_summary_screen.dart`, `trip_summary_sheet.dart` |
| §2 Compose | Schedule for later | ✅ | `schedule_picker.dart`, `near_term_ride_request_provider.dart` |
| §3 Searching | Create ride request (the signal) | ✅ | `ride_request_provider.dart` `createRide` |
| §3 Searching | Searching / radar UI | ✅ | `searching_screen.dart` |
| §3 Searching | **Live dispatch progress (wave, drivers notified, ETA)** | ✅ | `rider_dispatch_status_service.dart` + `_SdaDispatchCard`, 2s poll |
| §3 Searching | Late-join reflected while searching | ✅ | 8s `fn_seed_ride_matching_batch` re-seed + backend late-join |
| §3 Searching | Cancel search | ✅ | `searching_screen.dart` → `cancelExpiredRiderOpenRide`, `primary_cancel_row.dart` |
| §4 No driver | Notify-me background search | ✅ | `active_search_provider.dart`, `rider_notify_search_notifications.dart`, `rider_notify_live_activity.dart` |
| §4 No driver | Schedule / marketplace off-ramp | ✅ | `driver_search_expired_dialog.dart`, `matching_alternatives_card.dart` |
| §4 No driver | **Dedicated notify card on Home** | 🟡 | `active_notify_search_card.dart` exists but is **orphaned/unmounted** |
| §5 Driver found | Driver-assigned screen | ✅ | `active_ride_screen.dart` |
| §5 Driver found | Driver card (name, photo, car, plate, rating) | ✅ | `active_ride_screen.dart` `_DriverInfoCard` |
| §5 Driver found | **Live driver location on map** | 🟡 | works, but **5s RPC poll** not realtime; **no route polyline** |
| §5 Driver found | ETA to pickup | 🟡 | Haversine estimate (`_estimateEtaMinutes`), not routed ETA |
| §5 Driver found | Status change via realtime + push | ✅ | `active_ride_screen.dart` realtime, `rider_fcm_listener.dart`, `rider_notification_router.dart` |
| §6 Chat | Text chat | ✅ | `chat_screen.dart`, `chat_provider.dart` |
| §6 Chat | Canned quick-replies **in chat** | 🟡 | pings exist on active-ride sheet, not inside chat |
| §6 Chat | **Auto-translation** | 🔴 | none (raw `content` only) |
| §6 Chat | **Send location / photo** | 🔴 | text-only composer |
| §6 Chat | Masked call | ⚪ | excluded by product design (chat + pings cover contact) |
| §7 Safety | Share trip / live link | ✅ | `active_ride_screen.dart` `_shareRide` → `ride_shares` |
| §7 Safety | Report issue | ✅ | `report_screen.dart` + active-ride "Safety" → `/support` |
| §7 Safety | **Emergency / 112** | 🔴 | no emergency/SOS dial in rider app |
| §7 Safety | **In-ride Safety sheet (not just support link)** | 🟡 | "Safety" tile routes to `/support`, not a dedicated safety sheet |
| §8 Trip | "Driver arrived" state | ✅ | `active_ride_screen.dart` (`driver_arrived`/`arrived`) |
| §8 Trip | **Waiting meter + fee visible to rider** | ✅ | `_RiderWaitingFeeCard` (grace, rate, fee, waiver), 1s refresh |
| §9 Trip | Trip-in-progress ETA + live track | 🟡 | status/ETA present; tracking is 5s poll; no destination route line |
| §10 Complete | Trip complete → auto to rating | ✅ | realtime `completed` → `/rating` |
| §10 Complete | Fare summary / receipt | ✅ | `rider_receipt_screen.dart` (`fn_rider_receipt_for_ride`), `ride_detail_screen.dart` |
| §10 Complete | Rate the driver (stars/tags/comment) | ✅ | `rating_screen.dart` |
| §10 Complete | **Tip the driver** | 🔴 | no tipping anywhere in rider app |
| §10 Complete | **In-app payment capture at trip end** | ⚪/🔴 | cash/PIN/Tikkie model; no in-app card capture (see divergence note) |
| §11 History | Ride history list | ✅ | `rides_screen.dart`, `ride_history_provider.dart` |
| §11 History | **Filters / sort** | 🟡 | status filters only; no date/fare sort |
| §11 History | Per-ride receipt | ✅ | `rider_receipt_screen.dart`, `ride_detail_screen.dart` |
| §12 Payment | Payment-method prefs | ✅ | `payment_screen.dart` |
| §12 Payment | **Saved-card wallet / default on account** | 🟡 | prefs only (cash/pin/tikkie); no card wallet, no account payment section |
| §13 Rating | **Rider's own passenger rating shown** | 🔴 | drivers rate riders (`driver_rating_of_rider`) but rider app never displays it |
| §14 Scheduled | Upcoming/scheduled management (view/cancel/edit) | ✅ | `upcoming_ride_request_detail_screen.dart` |
| §14 Scheduled | Airport booking | ✅ | `airport_booking_screen.dart` |
| §14 Scheduled | Scheduled queued notice | 🟡 | `scheduled_ride_queued_notice.dart` **orphaned**; copy inlined in `scheduled_matching_fullscreen.dart` |
| §1–§9 Favorites | Add/remove favourite driver **UI** | 🟡 | `favorites_provider` has `addFavorite/removeFavorite` but **no screen calls them** |

**Headline:** The rider app already has the **full spine of the A→Z loop** (home → compose → search → match → track → arrive/wait → ride → complete → pay → rate → history), and in a few places it's **ahead** of the driver side (live dispatch-progress card, rider-visible waiting meter, notify-me background search with Live Activity). The gaps are mostly **depth/polish inside states we already own** (realtime tracking, chat richness, history filters) plus a handful of genuinely absent items (tipping, rider self-rating, emergency 112, saved-card wallet, comfort tier in UI) and **four orphaned widgets** to wire or delete.

---

## 18. Phase-by-Phase: What We Have · The Gap · How to Close It

### §1 — Home / Set Destination
- **We have:** rider-centered Mapbox home, "Where to?" hero, saved/recent/airport shortcuts, a 30s **aggregate** nearby-driver count with a zero-supply banner.
- **Gap:** supply on Home is a **single number**; per-category availability only appears later on the vehicle screen.
- **How to close (no restyle):** feed the already-loaded `nearby_category_supply_provider` snapshot into a compact chip on the existing Home sheet (reuse the `_VehicleNeedCard` count style). Pure data wiring — the provider already exists. Optionally delete or mount the **orphaned** `vehicle_category_supply_card.dart` (it duplicates `_VehicleNeedCard`).

### §2 — Compose the Ride (the offer the driver will see)
- **We have:** address search + swap, category picker (standard/taxibus/wheelchair), pet + favourites-first toggles, payment choice, trip summary, "Find my driver," save-for-later, scheduling.
- **Gap:** (a) **comfort** category is hidden (`_visibleCategories` omits it though the model/RPC support it); (b) **favourites-only** is marketplace-only; (c) **per-category fare estimate** uses a live-supply band while `tripCategoryEstimatesProvider` (+ `fn_estimate_trip_category_prices`) sits **unused**; (d) pickup contact name is on the payment step, not with the other prefs.
- **How to close (no restyle):**
  - Add `RiderVehicleCategory.comfort` to `_visibleCategories` — one line; the card renders itself. (Confirm the driver offer maps the `comfort` tag too, so both apps agree — this is the tier-tag sync point.)
  - Surface the existing favourites-only toggle on the vehicle screen using the same `_PreferenceSwitchRow` already used for favourites-first.
  - Decide **one** fare source: either retire `tripCategoryEstimatesProvider`, or switch the vehicle/summary price band to it so the **rider estimate == driver offer fare**. This is the single most important cross-app parity fix in the doc.

### §3 — Searching for a Driver
- **We have:** radar UI, **live dispatch-progress card** (wave, drivers notified, closest ETA via `rider_dispatch_status_service`), 8s batch re-seed that pulls in late-joining drivers, cancel.
- **Gap:** none material — this phase is **ahead** of the driver side. ✅
- **How to close:** n/a. (Keep the search window ≥ the driver late-join window so a driver coming online mid-search is still reachable — already the case via `kRiderDriverSearchWindow`.)

### §4 — No Driver Found
- **We have:** notify-me standing search (persisted + local notification + iOS Live Activity), schedule and marketplace off-ramps, try-again.
- **Gap:** `active_notify_search_card.dart` (the dedicated Home card for an in-progress notify search) is **built but never mounted** — Home relies on `ActiveBookingCard` + widget/live-activity instead.
- **How to close (no restyle):** either mount `ActiveNotifySearchCard` on Home behind the `activeSearchProvider` state, or delete it to remove dead code. The backend state already works; this is a wiring/cleanup decision.

### §5 — Driver Found / Live Tracking
- **We have:** `active_ride_screen.dart` with a full driver card (name, photo, car make/model/colour, plate, rating), a moving driver marker, an ETA estimate, and realtime + FCM status updates with sounds.
- **Gap:** location is a **5s RPC poll** (not Supabase Realtime), there's **no route polyline / camera-follow**, and ETA is a straight-line Haversine estimate, not a routed ETA.
- **How to close (no restyle):**
  - Swap `driver_tracking_provider`'s 5s poll for a Supabase Realtime subscription on `driver_locations` (same data, fewer round-trips, smoother marker). Provider-only change; UI untouched.
  - Draw the pickup/destination route line on the existing Mapbox instance (add a line layer in the map setup already present in `active_ride_screen.dart`).
  - Optional: replace the Haversine ETA with a routed ETA from the same directions source the map uses. Data-only.

### §6 — Chat
- **We have:** realtime text chat gated to active-ride statuses; canned **pings** on the active-ride sheet.
- **Gap:** **no auto-translation**, canned replies aren't **inside** the chat screen, no **send location/photo**.
- **How to close (no restyle):**
  - **Auto-translate** (highest-value comms fix for NL market): on render, if message locale ≠ device locale, call a translation edge function and show the translated line under the original — a small caption `Text` under the existing bubble, exactly Bolt's pattern. Mirror the same change on the driver side so both directions translate.
  - Surface the existing ping labels as tappable chips **inside** `chat_screen.dart`.
  - Location: post current GPS / share link as a message; photo: add image attachment to the `messages` insert. Composer already exists.

### §7 — Safety & Sharing
- **We have:** share-trip live link (`_shareRide` → `ride_shares` → public `/track/{token}`), report screen, support route.
- **Gap:** **no emergency/112**, and the in-ride "Safety" tile just routes to `/support` rather than a dedicated safety sheet.
- **How to close (no restyle):** turn the active-ride "Safety" tile into a small bottom sheet (reuse the existing sheet pattern) offering **Share trip · Report · Emergency call (112)**. Emergency is a `tel:112` launch + a logged `safety_event` — a few lines, no new design. This mirrors the driver's shield-always-reachable rule.

### §8 — Driver Arrived + Waiting
- **We have:** distinct "driver arrived / outside" state and a **rider-visible waiting card** (grace countdown, accruing fee, rate, waiver) refreshing every second.
- **Gap:** none material — this is **ahead** of / in parity with the driver side. ✅ (Just ensure the fee number here always equals the driver's rising fare — same source column `waiting_fee_cents`.)

### §9 — Trip In Progress
- **We have:** in-progress status, destination ETA, widget sync, share/safety reachable.
- **Gap:** tracking is the same 5s poll (see §5); no destination route line drawn.
- **How to close (no restyle):** same two fixes as §5 (realtime + polyline) automatically improve this phase; the fare shown should include waiting already added (carry `waiting_fee_cents` into the in-progress fare display).

### §10 — Complete → Pay → Rate (+ Tip)
- **We have:** auto-navigate to rating on `completed`, full driver rating (overall + 5 category dimensions + tags + comment), and a proper receipt (`fn_rider_receipt_for_ride`).
- **Gap:** **no tipping**; the rating screen doesn't show the final fare; no report/favourite affordance on the rating screen (FAQ implies both).
- **How to close (no restyle):**
  - **Tip:** add a tip chip row (e.g. €1 / €2 / €5 / custom) to the existing `rating_screen.dart`, writing to the same ride rating/receipt path; surface it in the driver's earnings tip field that already exists. Reuse the chip component.
  - Show the finalised fare (from the receipt RPC) at the top of the rating screen so rate-and-pay feel like one step.
  - Wire the existing `favorites_provider.addFavorite` to a heart on the rating screen (closes the favourites-add gap in §G4 too).

### §11 — Ride History + Receipts
- **We have:** history list with status filters, per-ride receipts, upcoming/scheduled segment.
- **Gap:** **no date/fare sort**; cancelled tab shows a hardcoded `'1'` badge (placeholder); driver rating not shown on past-trip detail.
- **How to close (no restyle):** add a sort control reusing the existing filter-chip row; make the cancelled badge dynamic (count from provider); add the driver's name/rating to `ride_detail_screen.dart` (data already available on the ride row).

### §12 — Payment Methods / Wallet
- **We have:** cash / PIN / Tikkie preference toggles saved to rider identity.
- **Gap:** **no saved-card wallet**, no default-method management from the account screen.
- **How to close:** add a payment section to `account_screen.dart` reusing the `payment_screen.dart` selector for defaults. A true **card wallet** (Stripe/Mollie) is a **model decision** — see divergence note; if HeyCaby stays cash/PIN/Tikkie, this reduces to "expose the existing prefs on account."

### §13 — Rider's Own Rating
- **We have:** nothing surfaced to the rider (drivers do rate riders via `driver_rating_of_rider`).
- **Gap:** **no rider self-rating UI.**
- **How to close (no restyle):** add a passenger-rating row to `account_screen.dart` reading the rider's avg from the backend (mirror of the driver's `driver_score_screen.dart`). Backend-plus-reuse; no new design.

### §14 — Scheduled / Upcoming + Airport
- **We have:** upcoming management (view/cancel/edit), airport booking, notify-me search, return-trip fare toggle, "ride again."
- **Gap:** `scheduled_ride_queued_notice.dart` is **orphaned** (copy is inlined in `scheduled_matching_fullscreen.dart`).
- **How to close:** delete the orphan or mount it where the inline copy lives — cleanup only.

---

## 19. Prioritised Backlog to Reach Bolt-Parity (rider, launch lens)

**P0 — parity that makes the two apps agree + the core loop feel right (cheap, mostly wiring):**
1. **One fare source** so the rider's estimate == the driver's offer fare (retire or adopt `tripCategoryEstimatesProvider`). (§2) — *the #1 cross-app sync fix.*
2. **Comfort category visible** in the picker + mapped to the driver's tier tag. (§2)
3. **Waiting fee number identical** on both sides (same `waiting_fee_cents` source). (§8) — verify, already close.
4. **Emergency (112) in an in-ride Safety sheet.** (§7)
5. **Tip the driver** on the rating screen. (§10)
6. **Rider self-rating** on account. (§13)
7. **Wire or delete the 4 orphans** (`active_notify_search_card`, `vehicle_category_supply_card`, `scheduled_ride_queued_notice`, favourites add/remove UI). (§1/§4/§10/§14)

**P1 — depth that matches Bolt polish:**
8. **Realtime driver location** (replace 5s poll) + **route polyline**. (§5/§9)
9. **Chat auto-translation** (both directions) + canned chips inside chat. (§6)
10. **Per-category supply on Home** + favourites-only on the instant vehicle screen. (§1/§2)
11. **History sort** + dynamic cancelled badge + driver rating on ride detail. (§11)
12. **Fare shown on the rating screen**; carry waiting fee into in-progress fare. (§9/§10)

**P2 — net-new / model-dependent (fast-follow, not launch-blocking):**
13. **Saved-card wallet** (Stripe/Mollie) + account payment section. (§12)
14. **Send location / photo** in chat. (§6)
15. **Routed ETA** (vs Haversine) for pickup + destination. (§5)

**⚪ Deliberately NOT doing (business-model divergence):**
- **Masked phone calling** — excluded by product design; chat + pings cover contact (same as driver doc).
- **In-app card capture at trip end** — HeyCaby's model is cash / PIN / Tikkie settled directly with the driver; the receipt records it. Only build in-app capture if a card wallet is adopted (P2 #13). This is the rider mirror of the driver's "no per-trip commission / no −€60 cutoff" divergence.

---

## 20. How to Close Without Touching Aesthetics — the rule of thumb (rider)

Every P0/P1 item is achievable by one of the same three moves as the driver doc, **none of which restyle the app**:

1. **Populate / unify a field** → an existing conditional widget renders itself (unify fare source, show comfort card, show rider rating, show driver rating on ride detail).
2. **Reuse an existing component** in a new place (ping chips inside chat, filter-chip row for history sort, payment selector on account, favourites heart on rating, hub-style safety sheet on the active ride).
3. **Flip one switch / swap one data source** (add `comfort` to `_visibleCategories`; swap tracking poll → realtime; `tel:112`; carry `waiting_fee_cents` into the in-trip fare).

Only the **saved-card wallet** (§12) and **send location/photo** (§6) are genuinely new surfaces — and both are P2 items that depend on a payments/product decision, not on visual design.

---

## 21. Rider ⇄ Driver Sync Map (the two apps side by side)

The whole point of this doc: confirm that for every driver screen there's the rider screen that drives it. This is the checklist to keep them locked together.

| Ride stage | Rider screen (this doc) | Driver screen (driver doc) | Shared source of truth | In sync today? |
|---|---|---|---|---|
| Idle | §1 Home + supply | §1 Home + demand | `driver_locations` / dispatch | 🟡 supply is aggregate on Home |
| Request | §2 Compose + §3 Searching | §2 Ride offer | `ride_requests` + invite payload | 🟡 fare source must be unified |
| Match | §3 dispatch progress | §2 accept | dispatch RPCs / waves | ✅ |
| To pickup | §5 live track | §3 en route + route details | `ride_requests.status`, `driver_locations` | 🟡 rider poll → realtime |
| Contact | §6 chat | §4 chat | `messages` | 🟡 no translation either side |
| Arrive/wait | §7 arrived + waiting meter | §5 arrived + waiting timer | `waiting_fee_cents`, `driver_arrived_at` | ✅ (verify equal numbers) |
| Safety | §8 share/report/SOS | §7 safety toolkit | `ride_shares`, `safety_event` | 🟡 rider lacks 112 |
| Ride | §9 in progress | §8 trip in progress | `ride_requests.status` | 🟡 rider poll → realtime |
| End | §10 pay + rate (+tip) | §9 rate rider | `ride_ratings`, receipt RPC | 🟡 no rider tip; ratings ✅ |
| After | §11 history / §12 payment / §13 rating | §10 history / §11 balance / §12 rating | `rides`, receipts, rating views | 🟡 rider self-rating missing |

**Read this table as the launch checklist:** every 🟡 is a place the two apps don't yet perfectly agree. None require redesign — they're the P0/P1 wiring items in §19.

---

### Appendix — note on sources

Unlike the driver doc (reconstructed from real Bolt driver screenshots), this rider doc is **inferred by mirroring** that driver flow: each rider signal/screen is derived from the driver action it must cause or the driver state it must reflect. The HeyCaby gap analysis (§17–§21), by contrast, is grounded in a **direct read of `apps/rider/lib` and `packages/`** — file paths and component names are exact and can be opened as-is.
