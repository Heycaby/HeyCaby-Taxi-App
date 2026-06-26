# Phase 2 Step 4 Design — trip.completed → Ledger

**Status:** ✅ Live on HEYCABY-TAXI (2026-05-20)  
**Report:** [PHASE-2-STEP4-POST-MIGRATION-REPORT.md](./PHASE-2-STEP4-POST-MIGRATION-REPORT.md)

---

## What Step 4 adds

| Object | Role |
|--------|------|
| `fn_billing_accrue_ride_fee` | Idempotent fee insert; fee from `fn_get_market_config` |
| `trg_billing_ledger_trip_completed` | Fires on `ride_requests.status` → `completed` \| `closed` |
| `billing.ride_fee_created` audit event | Correlates with `trip.completed` in audit trail |
| `waiver` reason | Added to canonical billing entry types |

**Not in Step 4:** €60 lock · cached balance · `billing_status` (Phase 3)

---

## Engineering rules

1. **Never hardcode fee** — always `fn_get_market_config('platform_fee_cents', country, city, zone)`.
2. **Never UPDATE ledger rows** — corrections = `reversal` append.
3. **One `ride_fee` per ride** — partial unique index (DB enforced).
4. **Idempotent accrual** — `ON CONFLICT DO NOTHING` + audit only on new row.

---

## Billing entry types (canonical)

| Reason | Use |
|--------|-----|
| `ride_fee` | €1 platform fee per completed ride |
| `reversal` | Admin dispute refund, void erroneous fee |
| `manual_adjustment` | Ops correction |
| `credit` | Settlement credit |
| `promotion` | Promotional waiver of fees |
| `waiver` | Explicit fee waiver (goodwill) |
| `refund` | Legacy / payment refund tracking |
| `settlement` | Driver paid outstanding balance |

V1 automation uses **`ride_fee` only**. Others are manual/service_role until Phase 3+.

---

## Test 3 business rule (admin reopen)

**Scenario:** completed → admin reopens → completed again

| Step | Ledger behaviour |
|------|------------------|
| First completion | `ride_fee` +100 created |
| Admin reopen (`completed` → `in_progress`) | **No change** — fee stays |
| Second completion | **No second fee** — unique index blocks duplicate |
| Admin voids erroneous completion | Ops appends `reversal` -100 (manual) |
| After reversal | Still **no second `ride_fee`** for same `ride_id` |

**Rationale:** One platform fee accrual per ride record lifetime. Reopen is operational; accounting correction is explicit reversal, not delete/edit. Prevents double-charge without allowing silent fee erasure.

---

## Five required smoke tests

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Status → `completed` | One `ride_fee` +100 |
| 2 | Accrue function called twice | One row; second call returns NULL |
| 3 | Complete → reopen → complete | One fee; original kept |
| 4 | Double accrue (concurrency proxy) | One fee row |
| 5 | Complete → `reversal` -100 | Net 0; rows append-only |

**Script:** `scripts/sql/smoke_phase2_step4_trip_completed_ledger.sql`

**True parallel sessions** (two `trip.completed` in separate DB connections): run on staging before high-traffic launch; partial unique index guarantees one winner.

---

## Rollback

Drop trigger + functions. Ledger rows created after deploy remain (append-only — use `reversal` if needed).

```sql
DROP TRIGGER IF EXISTS trg_billing_ledger_trip_completed ON public.ride_requests;
DROP FUNCTION IF EXISTS public.trg_billing_ledger_trip_completed();
DROP FUNCTION IF EXISTS public.fn_billing_accrue_ride_fee(uuid, uuid, text, uuid, uuid);
```

---

## Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260520160000_v1_phase2_step4_trip_completed_ledger_trigger.sql` | Step 4 SQL (repo) |
| `scripts/sql/smoke_phase2_step4_trip_completed_ledger.sql` | Five-test checklist |

---

## Approval gate

Say **"Approve Phase 2 Step 4 production"** after reviewing this doc + smoke script.

Post-deploy: run smokes on HEYCABY-TAXI, publish `PHASE-2-STEP4-POST-MIGRATION-REPORT.md`, update compliance %.
