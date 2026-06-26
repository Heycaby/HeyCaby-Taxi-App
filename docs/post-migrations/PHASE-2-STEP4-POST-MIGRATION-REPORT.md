# Phase 2 Step 4 Post-Migration Report — trip.completed → Ledger

**Date:** 2026-05-20  
**Project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`)  
**Migration:** `v1_phase2_step4_trip_completed_ledger_trigger`  
**Approval:** User — "proceed"

---

## What changed

| Object | Purpose |
|--------|---------|
| `fn_billing_accrue_ride_fee` | Idempotent platform fee from `fn_get_market_config` |
| `trg_billing_ledger_trip_completed` | `ride_requests.status` → `completed` \| `closed` accrues fee |
| `billing.ride_fee_created` | Audit event on new fee (correlation = ride_id) |
| `waiver` reason | Added to billing entry type enum |

**First automation touching money:** every completed ride with a driver now accrues €1 (NL default) unless duplicate.

**Not deployed:** `billing_status` · €60 lock (Phase 3)

---

## Why it changed

- Close the loop: trip completion → immutable ledger entry → auditable trail.
- Fee amount market-driven (Rotterdam today, London tomorrow — no migration).
- DB-enforced idempotency before lock/settlement layers.

---

## Smoke test results (all ROLLBACK — zero permanent rows)

| # | Test | Result |
|---|------|--------|
| 1 | Status → completed → +100 cents | ✅ |
| 2 | Double accrue function call | ✅ One row |
| 3 | Complete → reopen → complete | ✅ One fee kept |
| 4 | Double accrue (concurrency proxy) | ✅ One row |
| 5 | ride_fee + reversal → net 0 | ✅ |

**Production ledger rows after smoke:** 0

---

## Performance impact

- One INSERT + optional audit append per status transition to completed/closed.
- Indexed lookups via existing partial unique index — no full table scans.
- Pre-launch volume (~4 drivers) — negligible.

---

## Rollback

`scripts/sql/rollback_phase2_step4_trip_completed_trigger.sql` — drops trigger + functions only; ledger rows preserved.

---

## Risks introduced

| Risk | Mitigation |
|------|------------|
| Real rides now accrue fees on completion | Idempotent unique index; market_config for amount |
| Go path completes rides without driver_id | Trigger skips if `driver_id` NULL |
| No lock yet — drivers can accept while owing | Phase 3 M10/M11 |
| True parallel completion (two sessions) | Partial unique index; staging load test before scale |

---

## Architecture compliance

| Before | After | Delta |
|--------|-------|-------|
| 62% | **67%** | +5 |

M9 billing ledger: **Done** (schema + accrual). M10–M12 Phase 3 pending.

---

## Correlation trail (example)

```text
correlation_id = ride_uuid
  ride.created
  trip.completed
  billing.ride_fee_created
```

---

## Next

1. Observe live completions (pre-launch) — confirm fees accrue once  
2. Phase 3 M10: `drivers.billing_status`  
3. Phase 3 M11: €60 lock enforcement  

**Do not start Phase 3 until Step 4 stable + no duplicate billing observed.**

---

*Deployed 2026-05-20 on HEYCABY-TAXI.*
