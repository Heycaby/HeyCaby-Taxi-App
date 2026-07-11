# Supabase Release Promotion Log

This document records the HeyCaby staging-to-production Supabase promotion
contract and the production readback for each promoted change.

## Promotion Contract

Every Supabase change follows this order:

1. Inspect existing database objects and application callers.
2. Add one idempotent migration; do not duplicate tables, functions, triggers,
   policies, or configuration rows.
3. Apply the migration to staging with the Supabase MCP.
4. Run the feature's required acceptance test.
5. Read the resulting staging state back from Supabase.
6. Apply the identical migration to production with the Supabase MCP only after
   the acceptance gate passes.
7. Read production back and record the result here.

A compile, analyzer pass, or unit test is not a substitute for a required
physical-device or end-to-end smoke test. Production remains unchanged until
the acceptance gate defined for that feature passes.

## Promotion History

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
