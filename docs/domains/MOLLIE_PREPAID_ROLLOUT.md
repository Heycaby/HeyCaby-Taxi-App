# Mollie ride prepayments — project goal and rollout contract

## Project goal

Add secure Mollie prepayments to the functioning HeyCaby marketplace as an
optional, backend-owned branch: scheduled rides and Taxi Terug can require
payment after Driver acceptance, while instant rides may offer **Pay now** or
retain the existing **Pay Driver** flow. When every prepayment flag is off,
Rider and Driver behavior must remain exactly as it is today.

This is not a rebuild. Existing ride creation, dispatch, acceptance, cash, PIN,
Tikkie, Platform Balance, lifecycle, receipt, and cancellation paths remain in
place. Supabase owns state, Mollie owns payment processing and routing, and
Flutter only requests commands and renders backend projections.

## Domain authority

| Concern | Source of truth | Consumers |
|---|---|---|
| Ride assignment/lifecycle | `ride_requests` and canonical ride RPCs | Rider, Driver, Admin, notifications |
| Manual pay-driver confirmation | `fn_confirm_ride_payment` | Rider, Driver, receipts |
| Prepaid payment | `ride_payments` and `fn_ride_payment_apply_provider_snapshot` | Rider, Driver, Admin, receipts |
| Provider truth | Mollie payment fetched by `ride-payment-mollie-webhook` | Finance backend only |
| Driver Connect readiness | `driver_mollie_connections` projection, refreshed from Mollie | Driver, dispatch/prepay eligibility, Admin |
| Evidence timeline | `ride_audit_log` plus append-only `ride_payment_events` | Support, Finance, disputes, monitoring |
| Driver Platform Balance | Existing billing ledger and billing Edge Functions | Driver, dispatch, Finance |

Ride prepayment and Driver Platform Balance are separate domains even though
both currently use Mollie. They must not share intent rows, settlement rules, or
status transitions.

## Feature flags (all default false)

- `ride_prepaid_payments_enabled`: global kill switch.
- `ride_prepaid_driver_connect_enabled`: exposes Driver Mollie OAuth onboarding
  without enabling Rider checkout creation.
- `ride_prepaid_scheduled_enabled`: scheduled rides after acceptance.
- `ride_prepaid_taxi_terug_enabled`: Taxi Terug after acceptance.
- `ride_prepaid_instant_optional_enabled`: explicit Rider opt-in only.

No flag is enabled merely by deploying code or migrations.

## Implemented Flutter consumers

- Driver Settings exposes **Prepaid rides** only when
  `ride_prepaid_driver_connect_enabled` is true. The screen starts OAuth through
  `driver-mollie-connect`, renders `fn_driver_mollie_connection_status`, and
  refreshes through `driver-mollie-sync` after returning from Mollie.
- Rider Active Ride renders the prepaid card while the canonical ride is
  `accepted`, `driver_en_route`, or arrived and both the global and matching mode flags are true. Flutter sends
  no fare or commission amount. It opens the backend-issued checkout URL and
  renders `fn_ride_payment_snapshot` until the webhook confirms payment.
- Selecting **Pay driver** for an optional instant ride leaves the existing
  completion-time cash/PIN/Tikkie flow unchanged.
- The Driver callback scheme is `heycaby-driver://mollie/connect` on iOS and
  Android and routes to the Mollie connection status screen.

These consumers are dark-launched: all flags remain false. The canonical
`fn_driver_ride_start` command now calls the private
`fn_ride_prepayment_start_decision` boundary before changing a ride to
`in_progress`. When global plus scheduled/Taxi Terug flags are enabled, start is
allowed only when the newest `ride_payments` row is exactly `paid`, has
`paid_at`, has no refunded amount, and the ride payment projection is
`confirmed`/`paid`. Open, missing, stale, partially refunded, or client-claimed
payments fail closed and append `trip.start_blocked_prepayment` evidence.

Instant and marketplace rides are not start-gated. With flags off, scheduled
and Taxi Terug retain their released behavior. UI copy is never a lifecycle
enforcement boundary.

## State contract

`ride_payments.state` is backend-only:

`creating → open/pending/authorized → paid → routing_pending → routed`

Terminal/error branches are `failed`, `canceled`, `expired`,
`partially_refunded`, `refunded`, and `routing_failed`. A late provider callback
cannot move a paid/routed/refunded payment back to open, failed, canceled, or
expired.

Only a Mollie API re-fetch may confirm `paid`. The webhook request body is never
treated as payment proof. Amount and currency must match the immutable backend
fare snapshot before the ride's payment projection becomes `confirmed`.

## Secrets and Connect configuration

Required Edge Function secrets:

- `MOLLIE_API_KEY` (test credential during sandbox rollout);
- `MOLLIE_CONNECT_CLIENT_ID` and `MOLLIE_CONNECT_CLIENT_SECRET`;
- `MOLLIE_CONNECT_REDIRECT_URI`;
- `MOLLIE_CONNECT_APP_RETURN_URL`;
- `MOLLIE_TOKEN_ENCRYPTION_KEY` (32 random bytes, base64 encoded);
- `MOLLIE_RIDE_REDIRECT_URL`.

OAuth tokens are AES-256-GCM encrypted before database storage. They are never
returned by RPCs or written to logs. Rotate the encryption key only with a
planned token re-encryption procedure.

Mollie must confirm that the operator account has **Connect for Marketplaces**,
**Split Payments**, and **Delayed Routing** enabled before production routing is
activated. Delayed routing is required because funds are released only after
ride completion and validation. The default platform fee is `0` basis points,
preserving HeyCaby's current zero-commission ride behavior.

## Incremental implementation order

1. Deploy schema and functions with every flag false.
2. Configure a Mollie test OAuth app and test secrets.
3. Connect one internal Driver; sync until onboarding is verified.
4. Add cohort gating, then enable global + one mode flag for internal accounts
   only. The current global flags must not be used for public activation.
5. Create an accepted test ride, open checkout, pay, receive webhook, verify
   `ride_payments`, `ride_payment_events`, `ride_audit_log`, and the Rider
   projection.
6. Add and test cancellation/refund commands and configurable policy.
7. Add delayed routing after completed-ride validation, including retries and
   reconciliation.
8. Add the Admin read projection and role-bound refund/routing commands.
9. Run two-device regression certification for every existing critical flow.
10. Enable production only after Finance, Marketplace, Support, and Release
    owners sign off.

## Current implementation status (2026-07-15)

- Production schema and Edge Functions are deployed with every rollout flag
  still `false`.
- Required scheduled/Taxi Terug rides filter invitation and assignment to
  Mollie-verified Drivers, and the canonical ride-start RPC fails closed until
  a webhook-confirmed payment exists.
- Completed prepaid rides create a durable routing work item. The authenticated
  `ride-payment-route` function validates Driver ownership and ride completion,
  then uses a one-route-per-payment idempotency boundary and Mollie's Payment
  Routes API.
- The Mollie organization destination, fare, fee, and correlation ID are
  snapshotted when checkout is created; reconnecting an account cannot redirect
  an existing payment.
- Commission and cancellation settings are mutable only through
  `fn_admin_update_ride_payment_config`, which authorizes through `admin_users`
  and appends `ride_payment_config_audit` evidence.
- Webhook requests are rejected before a provider fetch when the Mollie payment
  ID is unknown locally, and provider metadata must match the local payment and
  ride IDs.
- OAuth code exchange and refresh use HTTP Basic authentication as required by
  Mollie's current OAuth token contract.

The branch remains **not approved for rollout** until the release gates in
`MOLLIE_PREPAID_IMPLEMENTATION_QA_REPORT.md` are closed.

## Required monitoring

- payment row stuck in `creating`, `open`, `pending`, or `authorized`;
- Mollie payment ID missing, duplicate, or amount/currency mismatch;
- webhook error/retry rate and stale transition count;
- paid payment where ride projection is not confirmed;
- completed ride with route not created or route failed;
- refund requested but not confirmed;
- connected Driver token refresh/revocation failures;
- encrypted token row with missing or inconsistent token fields;
- receipt amount differing from the immutable payment/fare snapshot.

Every structured log and alert includes `ride_id`, `ride_payment_id`, and
`correlation_id` when available. Provider tokens and Rider session tokens are
never logged.

## Rollback

First disable `ride_prepaid_payments_enabled`; this immediately prevents new
checkout creation without affecting existing rides or manual payment paths.
Do not delete payment rows or timeline events. Finance owns reconciliation of
already-open/paid payments. Database rollback is forward-only and must preserve
all audit evidence.

Operational owner: **Finance Backend**. Rollback commander and escalation path
remain a release decision and must be recorded in
`docs/domains/COMPATIBILITY_DECISION_LOG.md` before public activation.
