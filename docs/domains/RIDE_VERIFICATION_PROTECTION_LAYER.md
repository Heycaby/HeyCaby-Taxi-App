# Ride verification and payment protection layer

Date: 2026-07-15  
Production project: `fvrprxguoternoxnyhoj`  
Rollout status: installed, **all flags disabled**  
Production verdict: **NO-GO until physical sandbox certification**

## Goal and ownership

This is an additive security branch around the existing lifecycle. It does not
replace booking, dispatch, navigation, cancellation, completion, or payment.

| Concern | Authoritative source |
| --- | --- |
| Ride state | `ride_requests` and canonical lifecycle RPCs/triggers |
| Official pickup | Current `ride_requests.pickup_*` plus append-only `ride_pickup_versions` |
| Arrival, boarding, completion, and risk proof | `ride_verification_state` |
| Route proof | `ride_gps_track`, accepted only by the authenticated assigned-Driver RPC |
| Cases and disputes | `ride_protection_cases` plus `ride_audit_log` |
| Provider payment | Mollie-refetched `ride_payments` state |
| Driver fund routing | `fn_ride_payment_evidence_gate` followed by `ride-payment-route` |
| Support evidence view | `fn_admin_ride_evidence_timeline` |

Ride Operations Backend owns lifecycle verification. Trust & Safety owns case
review and controlled overrides. Finance owns routing and reconciliation.

## Installed controls

- Backend configuration owns every distance, GPS accuracy, speed, dwell, wait,
  PIN, destination, duration, route plausibility, and retention threshold.
- Official pickup changes are versioned. Near pickup they become a Driver
  approval request; only the backend applies an accepted location.
- Driver **Arrived** is a request carrying recent GPS evidence. The backend
  requires assignment, state, geofence, accuracy, speed, freshness, and dwell.
- Protected rides receive a per-ride PIN. The retrievable secret is isolated
  behind denied table grants; verification uses a salted SHA-256 digest. Failed
  attempts and expiry are enforced server-side.
- Transition triggers independently block arrival, start, completion, and
  cancellation bypasses from legacy or modified clients once flags are active.
- Route batches are actor-bound and reject oversized, stale, replayed,
  inaccurate, or malformed evidence when the route-evidence flag is active.
- Completion checks destination proximity, minimum reasonable time/distance,
  GPS jumps, boarding, start proof, and open safety cases. Suspicious cases stay
  `paid` and unrouted and create a support review instead of accusing a user.
- A verified arrival or started ride cannot be converted into automatic Rider
  cancellation/refund. It creates an append-only review case.
- No-show requires verified arrival, elapsed backend timer, no boarding,
  a recorded contact attempt, fresh Driver location, and continued pickup-area
  presence.
- Mollie routing calls the service-role-only evidence gate. A missing signal or
  open risk returns `ride_evidence_incomplete`; money remains paid and unrouted.

## Feature flags

All flags are backend-owned and currently `false`:

- `ride_arrival_verification_enabled`
- `pickup_locking_enabled`
- `boarding_pin_enabled`
- `route_evidence_enabled`
- `verified_completion_enabled`
- `payment_evidence_gate_enabled`

With these flags false, the existing instant cash/PIN/Tikkie and current ride
flows retain their released behavior. Enabling payment verification also
requires the existing prepaid/Mollie capability and cohort gates.

## UI consumers

- Driver arrival submits device evidence and waits for backend verification.
- Driver pickup shows the HeyCaby boarding PIN card only for a protected ride.
- Driver completion submits destination evidence and renders a review state
  without requesting Mollie routing when proof is insufficient.
- Rider arrival shows the backend PIN and warns not to share it before boarding.
- Rider in-progress replaces normal cancellation with **End trip early**, which
  opens a support case and explicitly does not promise an automatic refund.
- Admin Rides opens one evidence file containing lifecycle, verification,
  pickup versions, contacts, cases, route summary, and redacted payment state.

## Verification completed

- Production migrations `20260715063900` and `20260715064234` applied.
- Production `ride-payment-route` v6 deployed with JWT verification.
- Production SQL authority/grant/transition contract passed in a transaction.
- Driver suite: 171 passed, including all visual goldens and compact overflow.
- Rider suite: 79 passed.
- Shared verification/payment tests: 4 passed.
- Payment Deno tests: 8 passed.
- Admin tests, TypeScript, and production build passed.
- Monorepo boundary and domain-authority guards passed.
- Flutter analysis has no errors or warnings; shared package style infos remain.

## Release gates

Do not enable any flag until all of the following pass with internal test users:

1. Two physical phones complete scheduled, Taxi Terug, and optional instant
   Pay Now rides through arrival dwell, PIN, route evidence, completion, Mollie
   routing, receipt, and Admin review.
2. Instant Pay Driver, cash, PIN, and Tikkie regression remains unchanged.
3. Invalid/expired/locked PIN, stale GPS, impossible jump, early completion,
   outside-destination completion, no-show, and post-arrival cancellation are
   deliberately exercised and produce deterministic errors/cases.
4. Mollie webhook delay and duplicate start/completion/routing/refund commands
   are replayed and remain idempotent.
5. Support and Finance confirm the evidence view and manual-review runbook.
6. Named rollout, rollback, Finance, Ride Operations, and escalation owners are
   recorded in the compatibility decision log.

Rollback is flag-first and forward-only: disable the verification/payment
flags, preserve every evidence/payment row, and reconcile already-paid rides.
