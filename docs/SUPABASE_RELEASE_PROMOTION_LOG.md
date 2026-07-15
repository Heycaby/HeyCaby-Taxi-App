# Supabase Release Promotion Log

This document records the current HeyCaby production-only Supabase change
contract and production readback for each applied change. Entries before
2026-07-14 that mention staging are historical evidence only; staging project
`fdavszxncggswuiwggcp` is retired and must not be queried, migrated, or used for
new verification.

## Promotion Contract

Every Supabase change follows this order:

1. Inspect existing database objects and application callers.
2. Add one idempotent migration; do not duplicate tables, functions, triggers,
   policies, or configuration rows.
3. Compile and exercise the migration in an isolated local PostgreSQL harness.
4. Run the feature's static, unit, widget, integration, and authority gates.
5. Confirm production has no active customer fixture that the migration could
   disrupt, and define a forward-only rollback migration.
6. Apply the tested migration directly to production project
   `fvrprxguoternoxnyhoj` with the Supabase MCP.
7. Read production back, run safe production smoke checks, inspect advisors and
   logs, and record the result here.

A compile, analyzer pass, or unit test is not a substitute for a required
physical-device or end-to-end smoke test. When a physical test itself requires
production push credentials or a production share URL, deploy only the tested
surgical boundary, keep the release verdict conditional/NO-GO, and do not
manufacture customer data to claim completion.

## Promotion History

### 2026-07-14 - Rider lifecycle cron secret-authority repair

- Production project: `fvrprxguoternoxnyhoj`; staging was not touched.
- Production logs showed the every-20-minute lifecycle dispatcher change from
  HTTP 200 to four consecutive HTTP 401 responses after the Vault cron
  boundary was applied.
- Root cause: cron used `rider_agent_webhook_secret`, while the Edge Function
  preferred a separate `LIFECYCLE_DISPATCH_SECRET` environment value.
- `rider-lifecycle-dispatch` version 25 now resolves the service-role-only
  `fn_rider_agent_webhook_secret` Vault RPC as authority and retains both
  environment names only as compatibility fallbacks.
- Four Deno auth tests and full Edge type-check passed. A new authenticated
  `dry_run` exits before claiming lifecycle jobs. Production request `38288`
  reproduced 401 before the final repair; request `38289` returned HTTP 200 and
  `mode=dry_run` afterward without sending a notification or mutating a job.
- Rollback: redeploy Edge version 22 only if v25 causes a confirmed regression;
  that rollback reintroduces the known secret-drift failure and therefore also
  requires restoring the former cron credential path.

### 2026-07-14 - Production-only acceptance authority hardening

- Production project: `fvrprxguoternoxnyhoj`; staging was not touched.
- Migrations:
  - `20260714084930:driver_accept_runtime_eligibility`
  - `20260714084941:driver_accept_runtime_recheck`
  - `20260714090052:driver_accept_ride_fit_eligibility`
  - `20260714090109:scheduled_accept_authority`
- Local PostgreSQL 16 harnesses passed live/scheduled eligibility, SQL compile,
  grants, row-lock, expiry, future-pickup, accessibility, overlap, notify, and
  rejection-audit checks.
- Production readback verified all acceptance invariants, actor-bound grants,
  internal-helper denial, and the scheduled catalog's `security_invoker` mode.
- Production had no pending/accepted scheduled rides, no pending expired rides
  or invites, and no historical non-scheduled accept-after-expiry row at
  rollout. No customer fixture was mutated.
- Full Driver tests and Rider/Driver analysis passed; advisor totals remained
  security 480 and performance 350.
- Remaining gate: real competing-Driver concurrency and two-phone lock-screen,
  chat/ping, Taxi Terug, Rider update, and shared moving-trip tracking evidence.

### 2026-07-10 - NL Platform Balance bank details

- Migration: `20260710121000_platform_balance_bank_details_heycaby.sql`
- Staging project: `fdavszxncggswuiwggcp`
- Production project: `fvrprxguoternoxnyhoj`
- Acceptance evidence:
  - staging migration succeeded;
  - staging `fn_get_market_config` readback returned one enabled NL bank-transfer
    configuration;
  - driver bank-transfer parsing tests passed;
  - production migration succeeded;
  - production readback returned exactly one active NL configuration.
- Canonical recipient display name: `Hey Caby`
- Result: promoted and verified on production.

### 2026-07-10 - Driver background incoming-ride alerts

- Staging Edge Function: `driver-agent` version 12
- Staging webhook authentication: valid secret returned `200`; invalid secret
  returned `401`.
- Static, unit, visual, Deno, and unsigned iOS build checks passed.
- Production status: not promoted.
- Remaining acceptance gate: physical two-phone foreground, other-app,
  locked-phone, cold-start, exact-invite, accept, rider-update, and deduplication
  smoke matrix.
