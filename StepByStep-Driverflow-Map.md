# Step-by-Step Driver Flow Map — Bolt (Reference Analysis)

> **Purpose.** This document maps the **Bolt driver experience end-to-end (A → Z)** based on real on-road screenshots, so the HeyCaby driver app can be measured against a mature, proven ride-hailing flow. It describes **every screen and every modal**, what the driver sees, what action it triggers, and **why** the flow is designed that way.
>
> Scope: **driver side only** — from sitting online waiting for a request, through accepting, navigating, picking up, driving, ending the trip, and finally rating, history, earnings and reputation.
>
> Source: Bolt driver app (NL market, EUR, cash + in-app rides). Screens captured across two shifts; timestamps in the images are used to reconstruct the sequence.

---

## 0. The Flow at a Glance

```text
                        ┌─────────────────────────────────────────────┐
                        │          ONLINE / IDLE (Home)                │  ← earns nothing, waits
                        │  demand heatmap · today/weekly · Go offline  │
                        └───────────────────────┬─────────────────────┘
                                                 │ request pushed
                                                 ▼
                        ┌─────────────────────────────────────────────┐
   Decline ◀───────────│        RIDE OFFER (Accept / Decline)         │
   (no penalty shown)  │  price · surge · pickup+dropoff · rider ★     │
                        └───────────────────────┬─────────────────────┘
                                                 │ Accept
                                                 ▼
        ┌───────────────┐   navigate   ┌──────────────────────────┐
        │ Route details │◀────────────▶│  EN ROUTE TO PICKUP       │
        │ Cancel/Contact│              │  Waze/Google nav          │
        └───────────────┘              └───────────┬──────────────┘
                                                    │ arrive
                                ┌───────────────────▼──────────────────┐
                     chat ◀────▶│   ARRIVED · WAITING TIMER · fee bump  │
                (auto-translate)│   "01:15 Waiting" → Start trip        │
                                └───────────────────┬──────────────────┘
                                                    │ Start trip
                                ┌───────────────────▼──────────────────┐
   Safety toolkit ◀────────────│        TRIP IN PROGRESS               │────▶ Add stop
   Need a break   ◀────────────│        nav · ETA · End trip           │────▶ Route details
                                └───────────────────┬──────────────────┘
                                                    │ End trip
                                                    ▼
                        ┌─────────────────────────────────────────────┐
                        │   TRIP COMPLETE → rate rider → back online   │
                        └───────────────────────┬─────────────────────┘
                                                 ▼
        ┌───────────────┐   ┌──────────────────┐   ┌──────────────────────┐
        │  Rides history│   │  Balance/Payout  │   │  Star rating (rep.)   │
        └───────────────┘   └──────────────────┘   └──────────────────────┘
```

**Design principle running through the whole flow:** the app always shows **one primary action** as a large colored button at the bottom (Accept → Start trip → End trip → back online), and pushes everything else (chat, safety, break, route edits) into **modals/sheets** so the driver is never confused about "what do I press next" while moving.

---

## 1. Online / Idle — the Home screen

![Home screen, online, earnings popover and demand heatmap](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1426-6002969e-25d1-440e-880e-add5c5165b6c.png)

**State:** Driver is logged in and **online**, physically parked, waiting for a request. No ride yet.

**What's on screen:**
- **Live map** centered on the car (black cursor) with the driver's real position.
- **Demand heatmap** — colored zones (red/orange = high demand, green/neutral = low). This is the single most important idle tool: it tells the driver *where to reposition to get pinged faster and at higher fares.*
- **Earnings popover (top card):**
  - `€54.06 Today` — headline number, the emotional anchor for a driver.
  - `Weekly → €54.06` — tap-through to the weekly breakdown.
  - `Balances → -€13.04` — running account balance (debt/credit with Bolt; explained in §12).
  - A small **eye/hide icon** to privacy-hide earnings.
- **Primary action button:** `Go offline` (orange). While online this is the *stop* action — big, single, unmistakable.
- **Secondary controls (right):** recenter/location, filters (ride preferences).
- **Bottom tab bar:** `Home · Earn more · Rides · Help`.
- **`Offers`** strip peeking from the bottom (promotions / quests / bonuses).

**Why it's built this way:** an idle driver has exactly two jobs — **decide where to sit** (heatmap) and **know if it's worth staying out** (today/weekly earnings). Both are one glance away. The `Go offline` button is deliberately the only large CTA so the driver can end a shift with zero hunting.

---

## 2. The Ride Offer — Accept / Decline

![Incoming ride request with price, surge and route](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1377-cf361577-ba4b-4d33-9a44-3a9ee1606242.png)

**State:** A request has been dispatched to this driver. A countdown (implicit) is running; the offer auto-declines if ignored.

**What's on screen (top → bottom):**
- **Map with the full route drawn**: green dot = pickup, red pin = destination, blue line = the drive. The pickup badge reads `8.3 km · 12 min`.
- **`Decline`** pill, top-right — intentionally *small and out of the thumb's default path* so it isn't hit by accident.
- **Offer card:**
  - **Tags:** `Bolt` (product/tier) · `Terminal` (trip type / airport-terminal aware) · `1.1x High demand` (**surge multiplier** — tells the driver the fare is boosted).
  - `Out of radius` warning — the pickup is **farther than the driver's preferred pickup distance**; Bolt flags it so the driver knows this is a longer unpaid drive to collect the rider.
  - **`€21.80`** — the **estimated driver fare**, the decision number, shown largest.
  - `Declining won't affect acceptance rate` — a reassurance line that removes the psychological penalty of declining a bad/out-of-radius job.
  - **Rider identity + reputation:** `Ruth • 5.0 ★`.
  - **Two-leg breakdown:**
    - `16 min • 17.1 km` → pickup address (`C.D. Tuinenburgstraat 93, Rotterdam`).
    - `12 min • 8.3 km` → destination (`Goudse Rijweg 701, Rotterdam`).
- **Primary action:** `Accept` (large green, bottom).

**Why it's built this way:** the driver makes a **profit/loss decision in ~5 seconds**. So the screen front-loads the three things that decide it: **fare (€21.80), how far to pickup (out-of-radius / 16 min), and how far the actual paid trip is (12 min / 8.3 km)** — plus surge and rider rating. Accept is huge and green; Decline is tiny and consequence-free. This maximizes good accepts and minimizes accidental ones.

---

## 3. En Route to Pickup — Route Details sheet

![Route details sheet en route to pickup](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1415-1c9995f1-b083-4c64-9039-a1b05bb0fbe8.png)

**State:** Offer accepted. Driver is now driving **to the rider**. Navigation is active; this **Route details modal** is the control panel for the leg.

**What's on screen:**
- Header: `Route details` with **`Bolt · € 18,00`** (the confirmed fare for this job).
- **Destination row:** `Zwartendijk 11, Monster 2681 LM` (the rider's drop-off — shown so the driver already knows where the trip ends).
- **`Cancel Order`** (red ✕) — the driver-side cancellation path (with its own reason flow / possible penalties behind it).
- **`Contact Mădălina`** — opens chat/call with the rider (see §4).
- **`Waze` · Change** — the chosen navigation app; `Change` swaps between Waze / Google Maps / in-app.
- **Primary action:** `Stop new requests` — the "no back-to-back dispatch" toggle. It lets the driver finish this ride **without** immediately being handed another, without going fully offline.

**Why it's built this way:** once moving, the driver needs only four things reachable without leaving nav: **cancel, contact rider, change nav app, and stop the next auto-dispatch.** Everything is one tap. The fare and final destination are pinned at the top so there are no surprises.

---

## 4. Communicating with the Rider — In-app Chat (auto-translated)

![In-app chat with keyboard open](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1417-f40598ca-9e58-4355-a6c3-cb57fc1a514d.png)
![In-app chat with quick-reply chips](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1418-bc2aa4f3-2c37-4c9a-8949-356b8a1d384f.png)

**State:** Driver ↔ rider messaging, typically used near pickup ("I'm here", "2 min away").

**What's on screen:**
- Header: rider name `Mădălina` + pickup address `Daguerrestraat 18, Den Haag 2561 TT`, with a **phone icon** for a masked call.
- **Auto-translation in action:** the rider wrote `Sunt pe drum` (Romanian); the app shows **`Translated automatically → On my way`** underneath. The driver replied `I'm here`.
- **Quick-reply chips** (tap-to-send, no typing): `👋`, `I'm here`, `On my way`, `Send photo of your location`, `I'll arrive in 2 min`.
- **Free-text field** + send, with the keyboard shown in the first image.

**Why it's built this way:** drivers and riders frequently **don't share a language**, and the driver **should not be typing while driving**. Two features solve both: **automatic two-way translation** (removes the language barrier entirely) and **one-tap canned messages** (removes typing). `Send photo of your location` is specifically there to solve the hardest last-100-meters problem — finding a rider in a busy or ambiguous pickup spot.

---

## 5. Arrived & Waiting — the Waiting timer + fare bump

![Arrived at pickup, waiting timer 01:15, Start trip](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1416-6caccccd-540f-4e3d-a7ab-931d07aa2312.png)

**State:** Driver has reached the pickup and is **waiting for the passenger to get in**.

**What's on screen:**
- Map shows the car at the pickup with a **`Wait here`** label at the exact stop point.
- Bottom card:
  - **`01:15 Waiting`** — a **live waiting-time counter**. After the free wait window, waiting starts accruing a fee.
  - Pickup address `Daguerrestraat 18, Den Haag 2561 TT`.
  - Rider `Mădălina 5.0 ★`.
  - **`Bolt · € 20,00`** — note the fare is now **€20** vs **€18** en route (§3): **the waiting time has already increased the fare.** This is the visible proof that the waiting timer is monetized in the driver's favor.
- **Primary action:** `Start trip` (green) — pressed once the rider is in the car.

**Why it's built this way:** waiting is the most common source of driver frustration and lost income. Bolt makes it **fair and transparent**: a running clock the rider is implicitly accountable to, and a fare that **visibly ticks up** so the driver sees they're being compensated. The driver stays in control of the state transition — the trip only starts when the driver taps `Start trip`, never automatically.

---

## 6. Support Modal — "Need a break?"

![Need a break modal](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1420-1c1fa5a3-5df5-4851-8fea-06f08754d31d.png)

**State:** Driver invoked the break control (from the "stop hand" icon / menu).

**What's on screen (centered modal over a dimmed map):**
- Title: **`Need a break?`**
- Body: *"Taking a break means that after completing your **last accepted ride**, you will not receive new requests."*
- Buttons: **`Start break`** (green, primary) and **`Cancel`** (grey, secondary).

**Why it's built this way:** fatigue management + regulatory driving-time rules. The wording is crucial: it guarantees the driver **won't be stranded mid-job** — the break begins only *after the current ride finishes*, so no income is lost and no rider is abandoned. It's a soft "wind down" instead of a hard "go offline now."

---

## 7. Support Modal — Safety toolkit

![Safety toolkit modal](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1419-2698f874-6631-47b7-a296-1f52c7cd61a9.png)

**State:** Driver opened the safety/shield control (top-right shield icon).

**What's on screen (bottom sheet):**
- Title `Safety toolkit` — *"Features to help you feel safe and secure while driving."*
- **`Emergency call`** (red) — *"Call the local authorities"* (one-tap 112/911).
- **`Share trip details`** — *"Share trip status and location"* with an info (ⓘ) affordance; sends a live trip link to a trusted contact.
- **`Audio recording`** — *"Start recording"* — in-app trip audio capture for dispute/safety evidence.
- Footer note: *"…for security reasons, your trip may be recorded by a passenger."*

**Why it's built this way:** safety is a **trust and retention** feature for both sides. It's always reachable via a fixed shield icon (not buried in menus), and it escalates in severity: share → record → call authorities. Making the driver aware they *may be recorded by the passenger* also nudges good behavior and sets expectations.

---

## 8. Trip In Progress — navigation + Route details (Add stop)

![Trip in progress, 18 min, End trip](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1422-b8bdda1b-9d34-4813-9fea-2703f5f82bcf.png)
![Route details during trip with Add stop](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1421-41862d45-21cd-455f-9042-ad279769e1ba.png)

**State:** Rider is in the car, `Start trip` pressed; driver is driving to the **destination**.

**What's on screen — the driving view (first image):**
- Full-screen navigation (blue route on Daguerrestraat), nav app badge top-left.
- Bottom card: **`18 min`** ETA + destination `Zwartendijk 11, Monster 2681 LM`.
- **Primary action:** `End trip` (**red**) — the color deliberately changes from green (start) to red (end) so the driver never confuses the two.
- Chat bubble icon stays reachable.

**What's on screen — Route details during trip (second image):**
- `Route details` · `Bolt · € 18,00`.
- Destination `Zwartendijk 11, Monster 2681 LM` with **`Change`** (destination edit if the rider changes their mind).
- **`Add stop`** — insert an intermediate waypoint (multi-stop trips), which recalculates the fare.
- `Contact Mădălina`, `Waze · Change`, and again `Stop new requests`.

**Why it's built this way:** during the paid leg the driver needs **navigation dominance** (big map, big ETA) with the money-affecting edits (`Add stop`, `Change` destination) tucked in the route sheet so a stray tap can't alter the fare. The single red `End trip` is the only large CTA, mirroring the Accept/Start pattern — **one obvious next action per state.**

---

## 9. Trip Complete → Rate the Rider → Back Online

**State (transition, follows `End trip`):** Fare is finalized, the driver is prompted to **rate the rider** (1–5 ★, optional tags/notes), then is returned to the **online Home** state (§1) to receive the next request — unless `Stop new requests`/`break` was set, in which case dispatch pauses.

**Why it's built this way:** mutual rating is the backbone of marketplace trust. Collecting it **immediately after `End trip`**, while the interaction is fresh, maximizes completion and data quality. Then the loop closes straight back to §1 so a working driver's idle time between fares is minimized.

---

## 10. Rides History

![Rides history, Finished filter](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1425-dcb143fb-d90b-43da-a89a-b8c6dbc40091.png)

**State:** Driver reviewing completed work (via `Rides` tab).

**What's on screen:**
- Title `Rides` with filter chips: **`Finished ▾`** · `Sort ▾` · `Date ▾` · `Payment ▾` · (Time…).
- A dated list of trips, each row: date/time, "Near <street, city, postcode>", a **payment-method icon**, the **payout amount** (e.g. `€20.93`, `€18.55`, `€14.58`…), status `Finished`, and a chevron into the receipt/detail.
- Bottom tabs `Home · Earn more · Rides · Help`.

**Why it's built this way:** drivers need to **verify they were paid correctly** and reconcile cash vs in-app trips. Filters by status/date/payment make disputes and bookkeeping fast; each row drills into a full fare breakdown. The payment icon per row lets a driver instantly separate cash jobs (which affect balance, §12) from card jobs.

---

## 11. Earnings & Balance

![Balance screen with Balances explainer modal](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1427-a5799185-1e38-43ce-866a-8a8e75908271.png)

**State:** Driver inspecting money owed/earned (`Balances` from the Home popover, §1).

**What's on screen:**
- Header **`-€13.04`** — current balance (negative = the driver owes Bolt, typically from **commission on cash rides**).
- Warning banner: *"If your balance reaches **-€60.00**, you'll lose access to cash rides."* — the hard limit that forces settlement.
- Info: *"Payments may take up to 12 hours to appear…"*
- **`Balances` explainer modal:** *"The amount of money that remains in a deposit account. If it's negative it represents the amount of debt. **Doesn't include cash.** Full financial information and reports are available in the Driver Portal."* with `Close`.
- Ledger rows beneath: `Bolt commission -€8.93`, `Weekly Payout -€212.76 (Bolt → You, June 29)`, `In app trips +€133.90`.

**Why it's built this way:** with **cash rides**, the platform can't deduct its commission at source, so it accrues as **negative balance** the driver must top up. The **-€60 cutoff** protects Bolt from runaway debt while warning the driver early. The explainer modal exists because "balance" is genuinely confusing (it *excludes cash in hand*), so Bolt defines it inline to reduce support tickets.

---

## 12. Reputation — Star rating

![Star rating breakdown 4.94](/Users/heycaby/.cursor/projects/Users-heycaby-HeyCaby-main/assets/IMG_1428-4dd7ee7d-457b-4ca6-8e67-a95a2fdec647.png)

**State:** Driver reviewing their own rating/reputation.

**What's on screen:**
- **`★ 4.94`** with **`+0.12`** trend, *"Based on your last 50 ratings. Ratings don't update in real time."*
- **Rating trend** line chart.
- **Ratings breakdown:** `5★ = 48`, `4★ = 1`, `3★ = 1`, `2★ = 0`, `1★ = 0`.
- **`What riders didn't like`** → *"No feedback yet."*
- **`What riders liked`** → `👍 Excellent service`, `👍 Good conversation`, `👍 Nice vehicle`.

**Why it's built this way:** rating is the driver's **license to keep working** (fall too low and you're deactivated). Showing a **rolling 50-ride window** means one bad night doesn't haunt forever and recent improvement is rewarded (the `+0.12`). Splitting **liked vs didn't-like tags** turns an abstract number into **actionable coaching** ("be cleaner", "talk less/more") instead of a vague score.

---

## 13. State Machine Summary (for implementation)

| # | State | Driver sees | Primary CTA | Key modals reachable | Exit condition |
|---|-------|-------------|-------------|----------------------|----------------|
| 1 | **Online/Idle** | heatmap, today/weekly, balance | `Go offline` | earnings popover, filters | request received → §2 |
| 2 | **Offer** | fare, surge, pickup+dropoff, rider ★ | `Accept` | (Decline) | Accept → §3 / timeout → §1 |
| 3 | **En route to pickup** | nav to rider, fare, destination | `Stop new requests` | Route details, Cancel, Chat | arrive → §5 |
| 4 | **Chat** (overlay) | messages, auto-translate, quick replies | send | call, send location/photo | back to current state |
| 5 | **Arrived/Waiting** | waiting timer, rising fare | `Start trip` | Chat, Safety, Break | Start trip → §8 |
| 6 | **Trip in progress** | nav to destination, ETA | `End trip` (red) | Route details, Add stop, Safety, Break | End trip → §9 |
| 7 | **Complete/Rate** | rate rider 1–5★ | submit rating | — | → §1 (or paused if break set) |
| — | **Break** (modal) | break confirmation | `Start break` | — | after current ride, dispatch pauses |
| — | **Safety** (modal) | emergency/share/record | Emergency call | — | returns to trip |
| A | **Rides history** | finished trips + payouts | (row → receipt) | filters | — |
| B | **Balance** | debt/credit, cash cutoff | top-up / portal | Balances explainer | — |
| C | **Star rating** | 4.94, breakdown, tags | — | — | — |

---

## 14. Cross-cutting Design Rules (what to copy for HeyCaby driver)

1. **One primary action per state.** Exactly one large colored button at the bottom, and its **color encodes intent** (green = go/accept/start, red = end/cancel, orange = stop/offline). Never two big CTAs competing.
2. **Money is always visible and always honest.** Fare shows on the offer, en route, at waiting (and it **visibly increases** with wait time), during the trip, and in history. Balance explains itself inline.
3. **Declining is safe.** "Declining won't affect acceptance rate" + a small, hard-to-mis-tap Decline. This keeps drivers honest and un-stressed and improves the quality of accepts.
4. **Don't make drivers type or translate.** Quick-reply chips + automatic two-way translation + "send my location/photo." Everything solvable in one tap while stationary.
5. **Modals for everything non-driving.** Chat, safety, break, route edits, earnings are **sheets/modals over the map** — the map + next-action never disappear.
6. **State only advances on an explicit driver tap.** `Accept`, `Start trip`, `End trip` are all manual. The app never silently changes the driver's state; this is what makes waiting fees, pickups and disputes defensible.
7. **Fatigue & safety are first-class, not buried.** Fixed shield icon; break that respects the current ride.
8. **Close the loop fast.** Rate → straight back to online, so a productive driver's dead time between fares is near zero.

---

## 15. HeyCaby Gap Analysis — Where We Stand vs This Bolt Flow

> **Ground rule for every fix below: do NOT change the app's aesthetics.** HeyCaby already has the screens, theme, buttons (`DriverButton`), sheets (`DriverRideFlowScaffold`), map chrome (`DriverMapFloating`) and colour tokens (`DriverColors`). Closing a gap means **wiring behaviour / data / one reused component into the existing UI** — not restyling. Where a Bolt feature conflicts with HeyCaby's business model (0% commission, no cash-debt model, no phone numbers), it's flagged as an **intentional divergence**, not a gap.
>
> Audit basis: full read of `apps/driver/lib` + `packages/`. Status legend: **✅ Present** · **🟡 Partial** · **🔴 Missing** · **⚪ Intentional divergence**.

### 15.1 Scorecard (whole flow at a glance)

| Flow phase (doc §) | Capability | Status | Where it lives today |
|---|---|---|---|
| §1 Home | Live driver-centered map | ✅ | `driver_home_screen.dart` (Mapbox + location puck) |
| §1 Home | Demand heatmap / hotspots | ✅ | on-map demand circles + `driver_hotspots_screen.dart` |
| §1 Home | **Surge / price-multiplier zones** | 🔴 | demand-only; no pricing multiplier concept |
| §1 Home | Today earnings while online | ✅ | `DriverEarningsPill` → `driver_earnings_modal.dart` |
| §1 Home | **Weekly total + balance while online** | 🟡 | weekly only in Earnings hub; balance only in drawer |
| §1 Home | Go online / offline control | ✅ | `three_state_toggle.dart` |
| §1 Home | **Offers / quests / bonus strip** | 🔴 | none on home |
| §2 Offer | Estimated fare | ✅ | `driver_opportunity_screen_body.dart` |
| §2 Offer | **Surge multiplier badge** | 🟡 | UI chip exists, no backing data column |
| §2 Offer | **Out-of-radius warning** | 🔴 | distance shown as neutral text only |
| §2 Offer | Pickup + destination ETA/distance | 🟡 | both legs render if fields present |
| §2 Offer | Rider name + **rating** | 🟡 | name ✅; rating chip has no data column |
| §2 Offer | Accept/Decline + countdown + reassurance | ✅ | `new_ride_request_screen.dart` |
| §2 Offer | **Vehicle tier / product tag** | 🔴 | only payment-method chip |
| §3 En route | External nav (Waze/Google) + change app | 🟡 | `driver_navigation_launcher.dart` (no Apple, no in-app TBT) |
| §3 En route | **"Route details" sheet w/ fare+destination** | 🟡 | trip summary exists, not a labelled Route-details sheet; no fare en-route |
| §3 En route | Contact rider | ✅ | `driver_ride_communication_sheet.dart` (chat + pings) |
| §3 En route | Cancel order | ✅ | `driver_cancel_ride_flow.dart` |
| §3 En route | Stop new requests (≠ offline) | 🟡 | `on_break` toggle, **en-route screen only** |
| §4 Chat | Text chat | ✅ | `driver_chat_screen.dart` |
| §4 Chat | **Auto-translation** | 🔴 | none |
| §4 Chat | Quick-reply chips | 🟡 | pings in comm sheet, not chat chips |
| §4 Chat | **Send location / photo** | 🔴 | text-only composer |
| §4 Chat | Masked phone call | ⚪ | excluded by product design |
| §5 Waiting | Arrived state | ✅ | `active_ride_screen.dart` → `markArrived` |
| §5 Waiting | Live waiting timer | ✅ | `at_pickup_screen.dart` + `driver_pickup_wait_service.dart` |
| §5 Waiting | Waiting fee + waiver | 🟡 | fee card + `fn_driver_waive_waiting_fee`; total fare not live |
| §5 Waiting | **Fare visibly rises with wait** | 🟡 | shown "added so far", not a rising total; not shown in-trip |
| §6 Break | Break mode | ✅ | `three_state_toggle.dart`, `driver_shift_timer_widget.dart` |
| §6 Break | **"Need a break?" confirm modal** | 🔴 | length-picker only, no confirm copy |
| §6 Break | **Defer dispatch until current ride ends** | 🔴 | pauses immediately everywhere |
| §7 Safety | Emergency call (112) | ✅ | `driver_hub_sections.dart` |
| §7 Safety | Share trip details | ✅ | `getOrCreateRideShareUrl` |
| §7 Safety | **Audio recording** | 🔴 | `record` package + strings only, no UI |
| §7 Safety | **In-ride Safety sheet** (Bolt-style) | 🟡 | lives in Driver Hub, not on trip screens |
| §8 Trip | End trip CTA (**red**) | 🟡 | present but uses green primary, not destructive red |
| §8 Trip | **Add stop / change destination** | 🔴 | none |
| §9 Rate | Rate the rider post-trip | ✅ | `rate_rider_screen.dart` |
| §10 History | Finished-rides list | 🟡 | list ✅, **no payment-method icon, no filters** |
| §10 History | Per-ride receipt | ✅ | `driver_ride_detail_screen.dart` + `driver_trip_receipt_body.dart` |
| §11 Money | Balance (debt/credit) + explainer | ✅ | `driver_platform_balance_body.dart` |
| §11 Money | Cash-debt cutoff (Bolt −€60) | ⚪ | HeyCaby is 0% commission / weekly platform balance |
| §11 Money | In-app vs cash trip split | 🔴 | payment only on ride detail |
| §12 Rating | Own star rating | ✅ | `driver_score_screen.dart` |
| §12 Rating | **5★–1★ histogram** | 🔴 | shows category sub-scores instead |
| §12 Rating | **Rating trend chart** | 🔴 | static score bar only |
| §12 Rating | **"What riders liked/didn't like" tags** | 🔴 | free-text comments only |

**Headline:** HeyCaby already has the **spine of the A→Z loop** (online → offer → accept → navigate → arrive → wait → start → drive → complete → rate → history/earnings). The gaps are mostly **depth and polish inside states we already own**, plus a handful of genuinely absent behaviours (add-stop, auto-translate, audio recording, break-confirm-with-deferral, rating depth).

---

## 16. Phase-by-Phase: What We Have · The Gap · How to Close It

### §1 — Online / Idle Home
- **We have:** live map, real demand overlay (on-map circles + full hotspots screen), `ThreeStateToggle` go-online, today's earnings pill.
- **Gap:** (a) no **weekly total + wallet balance** on the online view; (b) no **Offers/quests** strip; (c) demand overlay is riders-waiting, not a **surge price multiplier**.
- **How to close (no restyle):**
  - Reuse the existing `DriverMoneyDashboardHeader` (already built, currently unmounted) or extend `DriverEarningsPill`'s modal to add a **Weekly** row and **Balance** row — pull `thisWeek` from `driver_earnings_hub_body.dart` logic and `outstanding_cents` from the platform-balance provider. Pure data wiring into existing cards.
  - Offers strip: add one horizontally-scrolling row of the existing card component to `driver_home_sheet.dart` fed by a new `driver_offers` table (or reuse `Offers`/quests once defined). If no incentive program yet, keep it hidden — it's the only truly "new content" item and is optional for launch.
  - Surge: only meaningful once pricing supports multipliers (see §2 surge).

### §2 — Ride Offer
- **We have:** fare hero, Accept/Decline, countdown seeded from invite `expires_at`, "skipping won't affect this trip" reassurance, two-leg route rows, payment chip.
- **Gap:** surge chip is an **unfed stub**; **rider rating** chip has no data; **out-of-radius warning** missing; **product/tier tag** missing.
- **How to close (no restyle — the chips already exist):**
  - **Rider rating:** add `rider_rating` to the offer payload (the dispatch seed already joins `drivers`/rider identity; surface the rider's avg rating into `ride_requests`/invite payload). The star `_MetricChip` renders automatically once the field is non-null.
  - **Out-of-radius:** you already compute `pickup_distance_km`. Add a threshold check in `_RideOfferViewData` and reuse the warning-coloured `_MetricChip` variant (same component, `warning` token) when distance > driver's max pickup radius. No new widget.
  - **Surge badge:** requires a `surge_multiplier` (or `demand_multiplier`) column on `ride_requests`, populated by the dispatch/pricing layer. The `demandLabel` chip already renders it. This is a **pricing-model decision** — wire the column when surge pricing is introduced.
  - **Product/tier tag:** you already store `vehicle_category` (standard/comfort/taxibus/wheelchair). Map it to a chip using the existing `_MetricChip` — one line to add to the `Wrap`.

### §3 — En Route + Route Details
- **We have:** external Waze/Google launch with a preference toggle, trip summary (pickup/dropoff/rider), cancel, contact, `Stop new requests` (en-route).
- **Gap:** no single **"Route details" sheet** exposing **fare + destination + change-nav** in one place; **fare not shown en-route**; `Stop new requests` only on the en-route screen; no Apple Maps.
- **How to close (no restyle):**
  - Add fare to `DriverActiveTripBody`'s existing hero metric (you already load fare fields in `ride_in_progress_screen.dart` — do the same `_loadExpectedAmount` call en-route). Reuses existing `DriverRidePhaseHero`.
  - Promote the existing trip-summary + nav-change into a bottom "Route details" sheet using the existing `DriverRideFlowScaffold` sheet pattern; just add a title string `Route details` and the `Change` nav affordance already implemented in Preferences.
  - Expose `Stop new requests` on at-pickup and in-progress bodies too — the toggle method (`_toggleNewRequests`) already exists; add the same `DriverRideFlowAction` to those two bodies.
  - Apple Maps: add a `maps://` branch to `DriverNavigationLauncher.launchPreferred` + a third row in the existing Preferences nav list.

### §4 — Rider Chat
- **We have:** realtime text chat, phase-aware quick **pings** ("On my way", "Arrived", etc.).
- **Gap:** no **auto-translation**, quick replies live in the ping sheet (not as chat chips), no **send location/photo**.
- **How to close (no restyle):**
  - **Auto-translate:** on message render, if `sender`/device locale differs, call a translation edge function and show the translated line under the original (exactly the Bolt "Translated automatically" pattern). Add a small caption `Text` under the existing bubble — no layout redesign. This is the **highest-value comms gap** for a multilingual NL market.
  - Surface the existing ping labels as tappable chips **inside** `driver_chat_screen.dart` (reuse `_labelForPing`) so canned replies live where the driver is typing.
  - Send location: reuse `getOrCreateRideShareUrl` / current GPS to post a location message; photo: add an image attachment to the `messages` insert (composer already exists).

### §5 — Arrival & Waiting
- **We have:** arrived action, live 1 Hz waiting timer, grace + chargeable fee card, driver waiver (`fn_driver_waive_waiting_fee`), fee added to total on completion.
- **Gap:** the **fare doesn't visibly rise** during the wait (shown as "€X added so far" only, and not carried into the in-trip fare display).
- **How to close (no restyle):** compute `displayFare = baseFare + liveWaitingFee` and feed it into the **same** waiting-card metric and the in-trip hero (`ride_in_progress_screen.dart` should add `waiting_fee_cents` to its `_loadExpectedAmount`). Data change only; the Bolt "€18 → €20" effect appears automatically.

### §6 — Break
- **We have:** `on_break` mode via `ThreeStateToggle`, break length picker, shift timer, reminders.
- **Gap:** no **"Need a break?" confirmation modal**, and break **pauses dispatch immediately** rather than **after the last accepted ride**.
- **How to close (no restyle):**
  - Add a confirm dialog reusing the standard `AlertDialog`/`DriverButton` (same pattern as `confirmAndCancelDriverRide`) with copy: *"After your current ride you'll stop receiving new requests."* Wire `Start break` / `Cancel`.
  - Deferred pause: when a ride is active, set a local `pendingBreak` flag and call `setStatus('on_break')` in the ride-complete handler instead of immediately. Small state-machine tweak in the active-ride flow; no new screen. (The unused `driver_break_reminder_banner.dart` can host the "break starts after this ride" hint.)

### §7 — Safety Toolkit
- **We have:** 112 emergency call (logs a `safety_event`), share-trip live link — both in the Driver Hub.
- **Gap:** **audio recording** not implemented (package + strings exist); safety sheet **not reachable from the trip screens** like Bolt.
- **How to close (no restyle):**
  - Add a third `_SafetyRow` "Audio recording" in `DriverHubSafetySection` wired to the already-bundled `record` package (start/stop, upload to storage, log `safety_event`). The row component already exists.
  - Add a **shield icon** to the trip screens (`driver_active_trip_body.dart`, at-pickup, in-progress) that opens the **existing** hub safety section as a sheet — reuse, don't rebuild. This gives Bolt's "always one tap to safety while driving."

### §8 — Trip In Progress
- **We have:** navigation view, ETA, distinct per-state CTAs, complete action.
- **Gap:** **End trip is green**, not red; no **Add stop / change destination**.
- **How to close (no restyle):**
  - Change the complete-ride `DriverRideFlowBottomBar` to `DriverButtonVariant.destructive` (the red token already exists in `driver_button.dart`). One-enum change → matches Bolt's green-start/red-end semantics without touching layout.
  - Add stop / change destination: add an "Add stop" action in the Route-details sheet (§3) that inserts a waypoint into the ride and recalculates fare. This needs backend support (waypoints + fare recompute) — the **largest net-new** item; scope it as a fast-follow, not launch-blocking.

### §9 — Rate the Rider → back online
- **We have:** full post-trip rider rating (`rate_rider_screen.dart`) then return to online. **✅ No gap.**

### §10 — Rides History
- **We have:** chronological finished list (date/location/fare/status) + rich per-ride receipt with payment method, earnings, platform fee.
- **Gap:** list rows **don't show payment method**; **no filters/sort** (status/date/payment).
- **How to close (no restyle):**
  - Add `paymentMethod` to `MyRideSummary` (`getMyRides` select) and render the existing payment icon on the `DriverLedgerHistoryItem` row.
  - Add the **same filter-chip row already used** in `driver_finance_screen.dart` (`DriverFinanceDateFilter`) above the history list, plus a payment/status chip. Reuse the chip component; pass params into `getMyRides`.

### §11 — Earnings / Balance
- **We have:** platform balance with explainer, settle-via-Mollie, earnings hub with date filters + export, per-ride commission.
- **Gap:** no **in-app vs cash split** in aggregates.
- **How to close (no restyle):** add cash/card/in-app tallies to `DriverFinanceMetrics` and show them in the existing metrics grid. Data aggregation only.
- **⚪ Intentional divergence:** Bolt's **−€60 cash-debt cutoff** and per-trip commission do **not** map to HeyCaby (0% commission, weekly platform balance). **Do not build** the cutoff — the equivalent guard (`driver_platform_fee_gate.dart`) already protects go-online when the weekly balance is overdue.

### §12 — Star Rating / Reputation
- **We have:** own star score, category sub-scores (punctuality/cleanliness/…), recent passenger comments, ratings count.
- **Gap:** no **5★–1★ histogram**, no **trend chart**, no **liked/didn't-like tags**.
- **How to close (no restyle):**
  - Histogram: expose per-star counts from the `driver_my_rating` view and render with the existing bar component (same style as category bars) — Bolt's "5★ 48 / 4★ 1 …".
  - Trend: replace the static `LinearProgressIndicator` with a small sparkline fed by a rolling ratings series (reuse chart styling from the hotspots/earnings charts).
  - Tags: add structured feedback tags to the rider→driver rating write path; display as chips in the existing "what riders liked" area. Backend-plus-reuse; no restyle.

---

## 17. Prioritised Backlog to Reach Bolt-Parity (launch lens)

**P0 — behaviour that makes the core loop feel right (cheap, mostly wiring, no new screens):**
1. **End trip → red** (`destructive` variant). One-line, high signal. (§8)
2. **Fare visibly rises with waiting time** + carry waiting fee into in-trip fare. (§5)
3. **Rider rating on the offer** (populate `rider_rating`; chip already renders). (§2)
4. **Out-of-radius warning** on the offer (reuse warning chip). (§2)
5. **"Need a break?" confirm + defer dispatch until current ride ends.** (§6)
6. **Stop-new-requests on all trip states**, not just en-route. (§3)
7. **Weekly total + balance on the online home** (reuse existing hub data + money header). (§1)

**P1 — depth that matches Bolt polish:**
8. **Route details sheet** (fare + destination + change nav) reachable while driving; show fare en-route. (§3)
9. **Chat auto-translation** + canned reply chips inside chat. (§4)
10. **In-ride Safety sheet** (shield on trip screens) + **audio recording** row. (§7)
11. **Rides history**: payment-method icon on rows + filter chips. (§10)
12. **Rating depth**: 5★–1★ histogram, trend, feedback tags. (§12)
13. **Product/tier chip** on the offer (map `vehicle_category`). (§2)

**P2 — net-new / model-dependent (fast-follow, not launch-blocking):**
14. **Add stop / change destination** (needs waypoint + fare-recompute backend). (§8)
15. **Surge price-multiplier** zones + offer badge (needs pricing model). (§1/§2)
16. **Send location / photo** in chat; **Apple Maps** nav option. (§3/§4)
17. **Offers / quests** strip (needs incentive program). (§1)

**⚪ Deliberately NOT doing (business-model divergence):**
- Bolt's **−€60 cash-debt cutoff** and **per-trip commission** — HeyCaby is 0% commission with a weekly platform balance already guarded by `driver_platform_fee_gate.dart`.
- **Masked phone calling** — excluded by product design; chat + pings cover contact.

---

## 18. How to Close Without Touching Aesthetics — the rule of thumb

Every P0/P1 item above is achievable by one of three moves, **none of which restyle the app**:

1. **Populate a field** → an existing conditional chip/row/metric renders itself (rider rating, surge, product tag, out-of-radius, payment icon).
2. **Reuse an existing component** in a new place (money header on home, finance filter chips on history, hub safety section as a trip sheet, category-bar style for the star histogram, alert-dialog pattern for the break confirm).
3. **Flip one enum / add one data line** (End-trip → `destructive`; add `waiting_fee_cents` to the in-trip fare load; add `pendingBreak` to the state machine).

Only §8 add-stop, §1/§2 surge, and §1 offers are genuinely new surfaces — and each is a P2 that depends on a backend/pricing/incentive decision, not on visual design.

---

### Appendix — image index

| Screen (this doc) | File |
|---|---|
| §1 Home / online | `IMG_1426` |
| §2 Ride offer | `IMG_1377` |
| §3 Route details (to pickup) | `IMG_1415` |
| §4 Chat (keyboard) | `IMG_1417` |
| §4 Chat (quick replies) | `IMG_1418` |
| §5 Arrived / Waiting | `IMG_1416` |
| §6 Need a break | `IMG_1420` |
| §7 Safety toolkit | `IMG_1419` |
| §8 Trip in progress | `IMG_1422` |
| §8 Route details (Add stop) | `IMG_1421` |
| §10 Rides history | `IMG_1425` |
| §11 Balance | `IMG_1427` |
| §12 Star rating | `IMG_1428` |
