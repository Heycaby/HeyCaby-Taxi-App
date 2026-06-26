# Driver App Gap Implementation Plan (vs Bolt benchmark)

This document maps what the Driver app is currently missing compared with the benchmark screenshots, and defines an implementation order that is safe for pre-App-Store hardening.

---

## Goal

Close the operational UX gaps in the Driver app for real-world taxi driving flows:

- fast accept/decline decisions with enough data
- stable in-trip controls and communication
- clear post-trip exception handling
- reliable state transitions and review-safe behavior

This is not about cloning design; it is about shipping complete driver workflows.

### Business model guardrail (must stay true)

- HeyCaby does **not** take commission from ride payments.
- Rider pays driver directly (cash/card/direct transfer between rider and driver).
- Therefore, any post-ride payment workflow is for **driver bookkeeping/accounting/tax records**, not platform dispute/settlement.

## Communication guardrail (must stay true)

- Driver-rider chat is allowed **only** when a ride is active.
- Outside active ride state, chat/contact channel must be unavailable.
- If voice calling is not part of product scope, prioritize:
  - driver-triggered rider push nudge ("driver is outside/nearby")
  - in-app chat quick messages

---

## Priority Legend

- **P0** = blocking/critical for reliable core ride operations
- **P1** = high impact for usability and reviewer confidence
- **P2** = quality and competitiveness improvements

---

## Gap Map (Current vs Target)

## A to Z Ride Lifecycle (Target)

1. Incoming request -> accept / decline / timeout.
2. Accepted -> en route to pickup with route details and contact controls.
3. Arrived pickup -> one-tap rider nudge + "I am outside" message.
4. Start ride -> in-progress navigation + safety/contact actions.
5. Arrived destination -> bold "collect EUR X now" reminder for direct-pay rides.
6. Complete ride -> optional payment reconciliation record for accounting/tax.
7. Rider settlement reminder -> rider sees amount owed/extra owed after close.

This lifecycle is the baseline for implementation and testing.

---

## Driver-Rider Sync Contract (Must Match on Both Apps)

Every critical driver action must produce a rider-visible update (UI and/or push) with predictable timing.

- **Offer sent -> rider pending state**
  - Rider sees searching/offer state until driver accepts/declines/times out.

- **Driver accepted**
  - Rider transitions to "driver on the way" state.
  - Rider sees ETA + driver identity + vehicle details.

- **Driver declined / missed**
  - Rider receives immediate fallback behavior (re-match/search continuation).
  - No stale "driver coming" state.

- **Driver arrived at pickup**
  - Rider receives push/in-app nudge: "Your driver is here" / "Your driver is nearby".
  - Rider UI shows arrival status clearly.

- **Driver started ride**
  - Rider transitions to in-trip state.
  - Chat remains available while trip is active.

- **Driver arrived destination / completed**
  - Rider transitions to trip complete summary state.
  - Direct-pay reminder appears on rider side (amount owed/extra owed if applicable).

- **Driver payment reconciliation note saved**
  - Driver-side accounting record updates Finance/Tax.
  - Rider side should not show platform settlement language.

- **Driver issues receipt**
  - Driver can generate/send a simple receipt after ride completion.
  - Rider receives receipt in-app (optional push/email channel can be added later).
  - Both apps show identical totals and payer/payee roles.

- **Chat scope rule**
  - Driver and rider can chat only during active ride lifecycle states.
  - Chat entry points are hidden/disabled outside active states.

- **Cancellation / no-show paths**
  - Both apps must converge to the same terminal state and messaging.
  - No orphan states where one side is "active" and the other is "ended".

## P0

- **Ride offer card data density**
  - **Current:** basic pickup/destination + countdown accept/decline.
  - **Target:** include category, payment type, demand badge, offered fare, rider rating, and route context (current dropoff + next pickup distance/time).
  - **Why:** drivers need enough info to decide in seconds.

- **Decline/missed-request backend completion**
  - **Current:** decline flow is mostly local UI and return.
  - **Target:** explicit backend acknowledge for decline + missed request state and feedback modal.
  - **Why:** prevents stale offers, inconsistent matching state, and trust issues.

- **Unified in-trip control sheet**
  - **Current:** controls spread across screens/routes.
  - **Target:** persistent route details sheet in active trip with:
    - cancel order
    - contact rider
    - navigation app switch
    - stop new requests
  - **Why:** this is core daily driver workflow.

## P1

- **Contact options + chat quick actions**
  - **Current:** chat route exists; UX entry points are not consistently prominent.
  - **Target:** one-tap contact modal from active trip, quick replies, and clear send options.
  - **Why:** reduces friction and support incidents.

- **Driver-triggered rider nudge notification**
  - **Current:** no dedicated "driver is here/nearby" push action.
  - **Target:** tap action from active trip that triggers rider phone vibration/push.
  - **Why:** faster pickups and fewer missed contacts.

- **Safety toolkit in active ride context**
  - **Current:** safety features exist, placement is fragmented.
  - **Target:** dedicated active-trip safety panel (emergency call, share trip, audio recording if enabled).
  - **Why:** better in-ride safety confidence and reviewer story.

- **Post-trip price issue taxonomy**
  - **Current:** limited structured post-ride record entry.
  - **Target:** replace "payment issue dispute" language with direct-payment reconciliation:
    - expected fare
    - amount actually paid
    - payment method
    - variance reason (paid less / unpaid / adjusted / extra paid)
    - optional accountant note
  - **Why:** accurate tax/accounting records for independent drivers; no implication that platform settles payments.

- **Destination collection reminder**
  - **Current:** no hard reminder to collect money before final close.
  - **Target:** bold checkpoint at destination:
    - "Do not forget to collect EUR X"
    - Emphasize cash/direct methods
  - **Why:** prevents missed collections in real-life distraction moments.

- **Simple cross-app receipt**
  - **Current:** no guaranteed simple post-ride receipt exchange flow between driver and rider.
  - **Target:** after ride completion, driver can issue a receipt that clearly states:
    - ride id/date/time
    - payer (rider) and payee (driver)
    - expected fare
    - actual paid
    - payment method
    - variance/note (optional)
  - **Why:** transparent records for both parties and accountant-ready proof.

- **State continuity/back behavior**
  - **Current:** improved in several screens, still inconsistent in some flows.
  - **Target:** back always returns to previous context; fallback only when stack cannot pop.
  - **Why:** avoids user disorientation under pressure.

## P2

- **Map-first productivity controls**
  - **Current:** map and cards are available but less integrated.
  - **Target:** stronger map-first sheet and quick actions (accept next ride, stop requests, route details).
  - **Why:** higher operational efficiency.

- **Driver performance/rewards hierarchy**
  - **Current:** hub stats exist but could be more contextual.
  - **Target:** prioritize live operational cards over passive metrics in trip-time contexts.
  - **Why:** better focus and conversion.

- **Locale consistency**
  - **Current:** risk of mixed-language strings in some flows.
  - **Target:** enforce single-locale per session/screen in critical trip paths.
  - **Why:** professional polish and reviewer confidence.

---

## Implementation Sequence (Recommended)

1. **P0-A: Decline/missed-request hardening**
   - Add backend decline acknowledgment flow.
   - Add missed-request modal/state synchronization.
   - Ensure request expiration updates local and server state.

2. **P0-B: Offer card enrichment**
   - Extend request payload mapping and UI fields.
   - Add demand/payment/type badges and rider quality indicators.

3. **P0-C: In-trip route details sheet**
   - Build one consistent bottom sheet for active trip controls.
   - Integrate cancel, contact, nav app, stop-new-requests.

4. **P1-A: Contact and chat quick actions**
   - Add persistent contact entry point during assigned/arrived/in-progress.
   - Add quick-reply templates and clear send/call paths.

5. **P1-B: Safety toolkit panel**
   - Expose emergency/share/audio tools in active trip context.
   - Keep actions one tap away and visible.

6. **P1-C: Rider nudge + active-ride messaging**
   - Add "driver is outside/nearby" rider push trigger.
   - Add one-tap "I am outside" message action in arrived state.
   - Enforce active-ride-only chat availability.

7. **P1-D: Destination collection checkpoint**
   - Add bold collection reminder before final ride close.
   - Require explicit acknowledgment before continue.

8. **P1-E: Post-trip direct-payment reconciliation flow**
   - Add "Record payment received" form after ride completion (optional but easy to access).
   - Store expected vs actual amount, method, variance reason, and note.
   - Surface this in Finance/Tax and ride history for accountant export/use.

9. **P1-F: Receipt issuance + delivery**
   - Add "Send receipt" action after ride completion (or after reconciliation save).
   - Persist canonical receipt record linked to ride id.
   - Make receipt visible to rider and driver in trip history.

10. **P1-G: Back-navigation consistency sweep**
   - Audit all ride-flow screens for pop-first behavior.
   - Keep route fallback only where necessary.

11. **P2: UX polish and localization cleanup**
   - tighten card hierarchy
   - enforce locale consistency
   - add finishing details for production confidence

---

## Acceptance Checklist (Definition of Done)

- **Partial** — Decline updates backend and rider matching state correctly.
  - Implemented with backend endpoint fallbacks + rider-side terminal-state fallback handling.
  - Needs live backend confirmation for full server-consistency guarantee.
- **Partial** — Missed request feedback appears reliably and is server-consistent.
  - Driver missed-request modal is implemented; backend consistency depends on endpoint availability.
- **Done** — Driver can complete full flow on device:
  - request -> accept -> active -> arrived -> in-progress -> complete -> rate
- **Partial** — Rider side reflects each lifecycle transition in near real-time.
  - Realtime transitions are wired; requires physical two-device verification under network variance.
- **Done** — Driver can trigger rider nudge push from active trip.
- **Done** — Chat is available only while ride is active.
- **Done** — Destination collection reminder appears before final close for direct-pay rides.
- **Done** — Driver can message rider from active trip without dead ends.
- **Partial** — Safety actions are available in-trip and do not break ride flow.
  - In-trip controls include cancel/contact/nav/stop-new-requests; emergency/share/audio toolkit is not fully implemented as a dedicated panel.
- **Done** — Driver can save direct-payment reconciliation entries on completed rides.
- **Done** — Finance/Tax screen reflects expected vs paid amounts and variance notes.
- **Done** — Driver can send receipt after ride completion in <= 2 taps.
- **Done** — Rider can open the same receipt and values match exactly.
- **Done** — Back button behavior is consistent and context-preserving.
- **Partial** — No P0/P1 crashes or dead routes in ride lifecycle.
  - Static analysis passes for touched files; still needs full device + flow matrix execution.
- **Partial** — No cross-app state mismatch (driver and rider always converge to same ride state).
  - Core mapping is implemented; final proof requires end-to-end realtime test matrix run.

---

## Testing Matrix (Real Device)

- **Accounts:** 1 rider + 1 driver test account
- **Devices:** physical iOS devices preferred
- **Scenarios:**
  - Accept flow success
  - Decline flow success
  - Countdown expiry -> missed request
  - Arrived/start/complete sequence
  - Destination collection reminder appears and requires acknowledgment
  - Driver nudge push reaches rider device
  - Rider receives and displays "driver arrived/nearby" nudge correctly
  - Chat/send quick reply
  - Chat blocked when ride is not active
  - Contact rider options modal
  - Cancel order path
  - Stop new requests during active trip
  - Direct-payment reconciliation save and Finance/Tax visibility
  - Rider completion screen reflects owed/extra amount for direct-pay logic
  - Driver sends receipt and rider receives/opens it
  - Receipt totals and payer/payee labels match on both apps
  - Offline/poor network recovery
  - Force one side offline and verify eventual state reconciliation on reconnect

---

## Verification Runbook (Sign-off Required)

Use this section as the final gate before App Store submission. Mark each scenario with:
- `PASS` = observed working on real devices
- `FAIL` = did not behave as expected
- `BLOCKED` = cannot test due to backend/env dependency

For each scenario, capture:
- Date/time
- Driver app build version
- Rider app build version
- Test account IDs (masked)
- Evidence note (what was observed)

### Session Metadata Template

- Date:
- Driver build:
- Rider build:
- Driver account:
- Rider account:
- Network condition:
- Tester:

### Scenario Sign-off Sheet

- [ ] Accept flow success — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Decline flow success — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Countdown expiry -> missed request — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Arrived/start/complete sequence — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Destination collection reminder + acknowledgment gate — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Driver nudge push reaches rider device — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Rider displays "driver arrived/nearby" nudge correctly — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Chat/send quick reply during active ride — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Chat blocked when ride is not active — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Contact rider options modal/actions — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Cancel order path from active ride — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Stop/resume new requests from active ride — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Direct-payment reconciliation save + Finance visibility — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Rider completion owed/extra settlement display — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Driver sends receipt and rider opens receipt — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Receipt totals and payer/payee labels match — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Offline recovery (driver/rider) — `PASS / FAIL / BLOCKED` — Notes:
- [ ] Reconnect convergence after one side offline — `PASS / FAIL / BLOCKED` — Notes:

### Exit Criteria (Release Gate)

Do **not** mark final submission-ready unless all are true:

- Every P0 scenario is `PASS`.
- Every P1 scenario is either `PASS` or has a documented mitigation accepted by product.
- No `FAIL` items remain open.
- Any `BLOCKED` item has a dated owner and unblock plan.
- Cross-app lifecycle convergence validated at least once end-to-end.

---

## DEDUPED EXECUTION BOARD (NO-REWORK MODE)

Use this board as the single execution tracker for remaining work.  
Rule: extend existing implemented paths first; do not create parallel flows.

Status legend:
- `[x]` Done
- `[~]` Partial (implemented but needs verification/hardening)
- `[ ]` Missing

| Item | Status | Owner | Depends on | Next action | Duplicate guard |
|---|---|---|---|---|---|
| Decline backend consistency proof | [~] | Driver + Backend QA | A1 complete | Run real-device decline tests and capture backend state transitions in runbook | Reuse `new_ride_request_screen.dart` + `driver_api.dart`; do not add second decline flow |
| Missed-request server consistency proof | [~] | Driver + Backend QA | A1 complete | Validate countdown-expiry path against production endpoint behavior | Reuse existing missed modal + fallback endpoint logic |
| Rider lifecycle convergence proof | [~] | Rider + Driver QA | B1/B2/B3 complete | Execute full two-device matrix under normal + degraded network and record results | Reuse current realtime/status handlers; no new status enum variants unless bug proven |
| In-trip safety panel hardening | [~] | Driver | A2 complete | Decide whether emergency/share/audio becomes a dedicated panel in current action center | Extend `active_ride_screen.dart` action center; do not build a second in-trip control UI |
| P0/P1 crash-free release evidence | [~] | QA | Verification runbook | Complete all sign-off rows with PASS/FAIL/BLOCKED and mitigation owners | Use existing runbook checklist; do not create a separate test matrix doc |
| Cross-app state mismatch zero-proof | [~] | QA + Backend | B1/B4/B5 complete | Validate one full ride where both apps converge after reconnect/offline scenario | Reuse current rider/driver lifecycle screens and providers; avoid duplicate fallback state machines |

### No-Duplicate Preflight (Before Any New Change)

1. Check if target item is already marked `Done` or `Partial` in this file.
2. Search existing files in Track A/Track B before adding any new screen/provider/API.
3. If `Partial`, patch the current path; do not create alternative UX or endpoint route.
4. Add evidence (test outcome + date + build versions) directly in `Verification Runbook`.
5. Only introduce new files when an existing path cannot be safely extended.

---

## Risks / Dependencies

- Backend endpoints may need additions for full decline and nudge-push trigger support.
- Backend schema/API may need additions for reconciliation fields (expected, paid, method, variance, note).
- Backend schema/API likely needs a `ride_receipts` record and retrieval for both apps.
- Optional email receipt delivery requires consented channel and retry-safe delivery.
- Rider app may need owed/extra reminder UI after driver close on direct-pay rides.
- Push/event delivery must be reliable enough for lifecycle-critical rider notifications.
- Shared ride-state enum mapping between apps must stay version-compatible.
- Route-state synchronization must avoid race conditions during rapid request updates.
- Safety/audio features may require platform permissions and App Store disclosure alignment.

---

## Notes

- Hotspots entry is intentionally removed from Driver Hub for now and can be re-enabled later.
- Compliance/document gating remains separate and should stay strict for go-online eligibility.
- Replace wording in UI/flows:
  - avoid "payment dispute with platform"
  - use "record payment received", "accounting note", "tax record"

---

## Two Implementation Tracks (With File Targets)

Use these tracks in parallel where possible, but keep shared backend/schema contracts aligned before UI wiring.

## Track A: Driver Changes

### A1) Offer lifecycle hardening (accept/decline/missed)
- **Goal:** request states are fully acknowledged and deterministic.
- **Status:** ✅ Completed
- **Implemented:**
  - Incoming request countdown expiry now triggers best-effort backend decline + missed-request modal.
  - Explicit decline action acknowledges backend with resilient endpoint fallback.
  - Accept path still performs deterministic state handoff into active ride flow.
- **Files:**
  - `apps/driver/lib/screens/new_ride_request_screen.dart`
  - `packages/heycaby_api/lib/src/driver_api.dart`
  - `apps/driver/lib/providers/driver_state_provider.dart`
  - `apps/driver/lib/router.dart`

### A2) In-trip control sheet (route details/contact/nav/stop requests)
- **Goal:** one persistent operational control surface during active ride.
- **Status:** ✅ Completed
- **Implemented:**
  - Active ride now includes a unified action center with:
    - cancel order
    - contact rider (chat deep-link)
    - navigation app switch
    - stop/resume new requests
  - Cancel action uses backend cancel endpoint fallbacks and clears active ride state safely.
- **Files:**
  - `apps/driver/lib/screens/active_ride_screen.dart`
  - `apps/driver/lib/screens/at_pickup_screen.dart`
  - `apps/driver/lib/screens/ride_in_progress_screen.dart`
  - `apps/driver/lib/widgets/driver_map_floating.dart`
  - `apps/driver/lib/l10n/driver_strings.dart`

### A3) Rider nudge push + quick "I am outside" action
- **Goal:** driver can trigger rider vibration/push and send one-tap pickup message.
- **Status:** ✅ Completed
- **Implemented:**
  - At pickup screen exposes explicit rider nudge action (`outside`) and one-tap "I am outside" chat message.
  - Driver API nudge call supports backend endpoint variants for rollout resilience.
- **Files:**
  - `apps/driver/lib/screens/at_pickup_screen.dart`
  - `apps/driver/lib/screens/driver_chat_screen.dart`
  - `packages/heycaby_api/lib/src/driver_api.dart`
  - `apps/driver/lib/services/driver_data_service.dart`

### A4) Destination collection checkpoint (direct-pay reminder)
- **Goal:** bold reminder to collect money before final close.
- **Status:** ✅ Completed
- **Implemented:**
  - In-progress completion now requires a collection checkpoint confirmation dialog.
  - Dialog includes expected amount when available.
- **Files:**
  - `apps/driver/lib/screens/ride_in_progress_screen.dart`
  - `apps/driver/lib/screens/ride_complete_screen.dart`
  - `apps/driver/lib/l10n/driver_strings.dart`

### A5) Reconciliation form + Finance/Tax persistence
- **Goal:** expected vs actual paid record for accountant/tax.
- **Status:** ✅ Completed
- **Implemented:**
  - Ride complete screen captures expected amount, paid amount, payment method, and accounting note.
  - Finance screen now surfaces payment reconciliation records from the driver ledger feed for tax/accounting visibility.
- **Files:**
  - `apps/driver/lib/screens/ride_complete_screen.dart`
  - `apps/driver/lib/screens/driver_finance_screen.dart`
  - `apps/driver/lib/models/driver_payment_ledger_item.dart`
  - `apps/driver/lib/providers/driver_data_providers.dart`
  - `apps/driver/lib/services/driver_data_service.dart`

### A6) Receipt issue/send from driver
- **Goal:** driver sends simple receipt in <= 2 taps after completion.
- **Status:** ✅ Completed
- **Implemented:**
  - Post-ride flow includes direct "Send receipt" action on ride complete screen.
  - Payload includes payer/payee, expected and paid amount, method, and note.
- **Files:**
  - `apps/driver/lib/screens/ride_complete_screen.dart`
  - `apps/driver/lib/screens/driver_finance_screen.dart`
  - `packages/heycaby_api/lib/src/driver_api.dart`
  - `apps/driver/lib/services/driver_data_service.dart`
  - `apps/driver/lib/l10n/driver_strings.dart`

### A7) Active-ride-only chat guard (driver side)
- **Goal:** no chat entry if ride is not active.
- **Status:** ✅ Completed
- **Implemented:**
  - Driver chat screen enforces active-state gating (`assigned/arrived/inProgress/completingRide`) and blocks UI/send outside scope.
  - Chat route remains ride-scoped and state-validated via provider guard logic in-screen.
- **Files:**
  - `apps/driver/lib/screens/driver_chat_screen.dart`
  - `apps/driver/lib/router.dart`
  - `apps/driver/lib/providers/driver_state_provider.dart`

## Track B: Rider Response Changes

### B1) Driver accept/decline/missed state reflection
- **Goal:** rider UI always mirrors real driver state.
- **Status:** ✅ Completed
- **Implemented:**
  - Searching flow now routes correctly on realtime status updates (accept -> active; decline/missed/cancelled/rejected -> safe fallback).
  - Active ride flow now exits to matching/home when backend status leaves active states.
  - Upcoming ride detail and matching attach flows keep rider-side state synced with backend row status.
- **Files:**
  - `apps/rider/lib/providers/ride_request_provider.dart`
  - `apps/rider/lib/providers/booking_provider.dart`
  - `apps/rider/lib/screens/searching_screen.dart`
  - `apps/rider/lib/screens/upcoming_ride_request_detail_screen.dart`
  - `apps/rider/lib/services/booking_draft_storage.dart`

### B2) "Driver is here/nearby" nudge handling
- **Goal:** rider receives push/in-app signal promptly.
- **Files:**
  - `apps/rider/lib/services/rider_notify_search_notifications.dart`
  - `apps/rider/lib/services/rider_notification_lifecycle_service.dart`
  - `apps/rider/lib/widgets/rider_notifications_listener.dart`
  - `apps/rider/lib/screens/home_screen.dart`

### B3) Active-ride communication visibility
- **Goal:** contact/chat exposed only during active ride.
- **Status:** ✅ Completed
- **Implemented:**
  - Router guard blocks `/chat` route unless ride is in an active status.
  - Chat screen enforces the same rule at runtime and blocks sending outside active ride states.
- **Files:**
  - `apps/rider/lib/screens/rider_support_chat_screen.dart` (or ride-specific chat screen if split)
  - `apps/rider/lib/screens/home_screen.dart`
  - `apps/rider/lib/router.dart`
  - `apps/rider/lib/providers/booking_provider.dart`

### B4) Rider completion settlement reminder (direct-pay)
- **Goal:** rider sees owed/extra amount after driver close.
- **Status:** ✅ Completed
- **Implemented:**
  - Rider completed-ride detail now computes and displays `Outstanding`, `Overpaid`, or `Settlement complete` from receipt expected/paid values.
  - Direct-pay reminder copy remains visible in completed ride context.
- **Files:**
  - `apps/rider/lib/screens/trip_summary_screen.dart`
  - `apps/rider/lib/l10n/app_en.arb`
  - `apps/rider/lib/l10n/app_nl.arb`
  - `apps/rider/lib/l10n/app_localizations*.dart` (generated)

### B5) Receipt receive/view on rider side
- **Goal:** rider opens same receipt as driver with matching values.
- **Status:** ✅ Completed
- **Implemented:**
  - Dedicated rider receipt screen added and routed via `/receipt/:rideId`.
  - Receipt access added from completed ride detail and from ride history completed cards.
  - Rider API receipt fetch path wired with fallback handling.
- **Files:**
  - `apps/rider/lib/screens/trip_summary_screen.dart`
  - `apps/rider/lib/screens/account_screen.dart` (or ride history entry surface)
  - `apps/rider/lib/providers/booking_provider.dart`
  - `packages/heycaby_api/lib/src/rider_api.dart`
  - `apps/rider/lib/l10n/app_en.arb`
  - `apps/rider/lib/l10n/app_nl.arb`

## Shared Contract Layer (Both Tracks Depend On)

- **Goal:** one source of truth for status/events/receipt payload shape.
- **Files:**
  - `packages/heycaby_api/lib/src/driver_api.dart`
  - `packages/heycaby_api/lib/src/rider_api.dart`
  - `apps/driver/lib/services/driver_data_service.dart`
  - `apps/rider/lib/services/nearby_supply_service.dart` (if event stream touches matching updates)

Suggested shared payloads:
- `ride_state_event` (accepted, declined, missed, arrived, started, completed, cancelled)
- `rider_nudge_event` (outside, nearby)
- `direct_payment_reconciliation`
- `ride_receipt`

