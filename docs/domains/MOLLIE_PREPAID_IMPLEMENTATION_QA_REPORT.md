# Mollie prepaid extension — implementation and QA report

Date: 2026-07-15  
Environment reviewed: production Supabase `fvrprxguoternoxnyhoj`, Mollie test configuration  
Verdict: **NO-GO for enabling any prepaid rollout flag**

## Executive result

The prepaid branch is dark-launched behind the existing canonical mode flags,
the global kill switch, a new Mollie routing-capability switch, and backend
cohort gates. Released ride behavior remains unchanged: production has a 0%
cohort, no allowed Drivers, unconfirmed Marketplace routing capability, and all
prepaid flags false. Automated Rider, Driver, backend command, UI overflow, and
golden tests pass.

Production activation is not approved. There is no connected internal Driver,
no completed Mollie sandbox payment, no routed payment, and no evidence that
Mollie has enabled Marketplace Split Payments/Payment Routes for this account.
The canonical refund/routing command layer, cohort enforcement, alert records,
five-minute scanner, Admin client, and protected-ride evidence view are
deployed. Production activation is still blocked because the Mollie sandbox
and physical two-device verification scenarios have not run and external alert
delivery is not configured. Enabling flags before those gates close would
violate the release standard.

## Issues found and fixes applied

| Severity | Finding | Fix |
| --- | --- | --- |
| Critical | Required-prepay jobs could invite or assign a Driver without a verified Mollie destination. | Added one backend readiness decision shared by invite filtering and assignment guards. Instant rides remain unaffected. |
| Critical | Payment creation calculated commission and Driver amount but did not route funds. | Added authenticated, completion-bound, idempotent `ride-payment-route` using the Mollie Payment Routes API and a durable routing state. |
| High | Rider checkout disappeared when a Driver moved immediately from `accepted` to en-route/arrived. | Kept the card visible through en-route and arrival, using backend `booking_mode` instead of stale local mode. |
| High | A public webhook could force Mollie API reads for arbitrary payment IDs. | Local payment lookup now happens first; unknown IDs return `payment_not_found`, and Mollie metadata must bind to the local ride/payment. |
| High | OAuth token exchange/refresh sent client credentials in the request body. | Changed both flows to HTTP Basic authentication. |
| High | Routing destination could drift after Driver reconnect. | Snapshotted immutable `destination_organization_id` on payment creation. |
| High | Commission had configuration data but no canonical audited Admin command. | Added role-bound read/update RPCs, range validation, row locking, and append-only configuration audit. |
| Medium | Payment-domain foreign keys lacked covering indexes. | Added four additive indexes before rollout traffic. |
| Medium | New Rider card did not show the backend-authoritative amount. | Added localized amount copy and a compact-phone/1.3× text-scale regression test. |
| Medium | Driver received generic copy when prepayment readiness changed. | Added localized Mollie readiness copy and stale-opportunity dismissal behavior. |
| Critical | Mollie Connect could be mistaken for proof that Delayed Routing is enabled. | Added `mollie_marketplace_routing_enabled` plus a separate service-only capability-confirmation record. Both default false and are required by backend checkout/dispatch/start decisions. |
| Critical | Refunds, fees, reversals, and Admin retries had no shared command authority. | Added one service for route, full/partial refund, cancellation fee, no-show fee, route reversal, and void commands. Commands accept a ride ID, derive amounts and policies server-side, persist idempotency records, and audit the actor. |
| High | Mode availability was duplicated in the payment Edge Function. | Removed the TypeScript mode/flag decision and routed checkout through `fn_ride_prepayment_checkout_decision`, which is also consumed by assignment and ride-start protection. |
| High | Webhook retries, refunds, and chargebacks lacked durable operational evidence. | Added webhook delivery, refund reconciliation, chargeback, correlation, and operational-alert projections. Mollie re-fetch/webhook remains final state authority. |
| High | The requested rollout flag names duplicated deployed canonical flags. | Kept `ride_prepaid_scheduled_enabled`, `ride_prepaid_taxi_terug_enabled`, and `ride_prepaid_instant_optional_enabled`; no alias configuration rows were created. |
| Critical | Completed status alone allowed the Driver routing endpoint to release prepaid funds. | Added a service-role-only evidence gate requiring verified arrival, boarding, start, completion, clear risk, and payment eligibility. The shared Mollie command consumes it before creating a route. |
| Critical | A Rider could request normal cancellation after verified arrival or during a protected trip. | Added an independent transition trigger and canonical case command; the payment remains protected and no automatic refund is promised. |

## Source-of-truth validation

- Ride creation, assignment, lifecycle, and start remain owned by Supabase and
  canonical ride RPCs/triggers.
- Mollie is provider truth. A client response or redirect never marks a payment
  paid; only a server-side Mollie re-fetch through the webhook can do so.
- Flutter sends ride ID and explicit instant opt-in only. It sends no amount,
  commission, destination account, or payment status.
- Scheduled and Taxi Terug become required-prepay only when both the global and
  matching mode flag are enabled. The canonical start RPC blocks missing,
  open, stale, or refunded payment states.
- Instant rides remain Pay Driver by default. Only an explicit Rider Pay Now
  action creates a checkout.
- Driver Mollie readiness comes from `driver_mollie_connections`, refreshed
  from Mollie. OAuth tokens remain encrypted and are not projected to clients.
- Commission is read from `ride_prepaid_payment_config.platform_fee_bps`,
  snapshotted per payment, and is not hardcoded in Flutter or SQL calculations.
- Cancellation and no-show refund amounts are derived only from backend payment
  snapshots and audited policy values. Admin and mobile requests cannot supply
  an amount, platform fee, Driver share, or routing reversal amount.

## Production deployment verification

- Applied `harden_ride_prepayment_end_to_end` and
  `index_ride_prepayment_foreign_keys`, plus
  `mollie_payment_commands_cohort_alerts` migrations.
- Deployed active versions of `ride-payment-create`,
  `ride-payment-mollie-webhook`, `ride-payment-route`,
  `ride-payment-admin-command`,
  `driver-mollie-connect`, `driver-mollie-sync`, and
  `driver-mollie-oauth-callback` with the intended JWT settings.
- Verified all guard triggers and immutable route destination column exist.
- Verified authenticated/anonymous clients cannot execute the private Driver
  readiness helper; anonymous clients cannot execute Admin payment RPCs.
- Verified a fake webhook payment ID returns `404 payment_not_found` without a
  Mollie fetch and the routing endpoint rejects an unauthenticated request with
  `401`.
- Verified production still contains zero connected Drivers, zero ride
  payments, and zero routes. All prepaid and Connect flags remain false.
- Verified production cohort percentage is `0`, allowed Driver IDs is empty,
  Marketplace routing capability is unconfirmed, and duplicate alias flag rows
  do not exist.
- Ran the production alert scanner successfully; it found no payment-domain
  records requiring an alert.

## QA evidence

- Rider suite: **79 passed**.
- Driver suite: **171 passed**, including all golden tests.
- Driver compact-phone visual overflow tests passed at 320×568 and 1.3× text.
- Rider prepayment compact-phone test passed at 320×568 and 1.3× text.
- Shared API package: **3 passed**.
- Payment and command Deno tests: **8 passed**; all four deployed payment
  functions pass `deno check`.
- Production database hardening contract: passed inside a rolled-back
  transaction.
- Monorepo domain-boundary checks: passed.
- Flutter analysis: no errors or warnings; 14 pre-existing style infos in the
  shared API package.
- No simulator/emulator is available in this environment, so physical
  two-device checkout/return/deep-link behavior is not certified.

## Security advisor classification

- **Fix now — completed:** payment-domain foreign-key indexes.
- **Accepted intentional service boundary:** payment/audit/token tables have
  RLS enabled with no client policies and explicit client grants revoked.
- **Accepted authenticated command boundary:** payment snapshot, Driver status,
  and Admin RPCs are `SECURITY DEFINER` because they enforce actor/role checks
  internally and expose narrow projections.
- **Compatibility decision required:** legacy anonymous
  `fn_confirm_ride_payment` execution remains until caller/version decisions are
  approved; it was not revoked blindly.
- **Platform-owned:** `spatial_ref_sys` RLS is the only security advisor error
  and belongs to the PostGIS extension/platform boundary.

## Release blockers

1. Connect one internal Driver in Mollie test mode and sync until both payment
   and settlement readiness are verified.
2. Obtain written confirmation that Marketplace Split Payments/Payment Routes
   and delayed routing are enabled for the Mollie partner account.
3. Run a real scheduled sandbox ride end to end: accept, checkout, webhook,
   paid projection, start guard, completion, route, receipt, and timeline.
4. Repeat for Taxi Terug and optional instant Pay Now; regression-test instant
   Pay Driver, cash, PIN, Tikkie, cancellation, and Driver Platform Balance.
5. Sandbox-test the deployed idempotent full/partial refund, Driver
   cancellation, free/late Rider cancellation, no-show, and full/partial route
   reversal commands. Verify the connected Driver—not HeyCaby alone—is debited
   for routed reversals.
6. Certify the deployed Admin client evidence view and payment commands with
   Support and Finance using AAL2 accounts. Direct status/config table writes
   remain prohibited.
7. Configure dashboard/notification delivery for the persisted alerts covering
   route failure, refund failure/stall, connected-account divergence, webhook
   failure/retries, approaching unrouted deadline, chargeback, and low refund
   balance. Deliberately simulate each alert.
8. Add the remaining non-payment-domain alerts for stuck checkout,
   payment/projection divergence, Connect token refresh/revocation, and receipt
   mismatch. Every alert must carry ride, payment, Driver, and correlation IDs
   where available.
9. Name Finance, Marketplace, Support, rollback, and escalation owners in the
   compatibility decision log.
10. Complete physical Rider/Driver device certification and Finance/Support
    sign-off.

## Activation and rollback rule

Do not enable `ride_prepaid_payments_enabled`,
`mollie_marketplace_routing_enabled`, or any mode/Connect flag yet.
When every blocker is closed, enable only an internal cohort and one mode in
test mode. Roll back first by disabling the global flag; never delete payment,
route, refund, webhook, or audit evidence.
