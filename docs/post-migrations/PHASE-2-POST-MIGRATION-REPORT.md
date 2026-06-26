# Phase 2 Post-Migration Report — Steps 1–2

**Date:** 2026-05-20  
**Project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`)  
**Migration:** `v1_phase2_billing_ledger_schema_only`  
**Approval:** CTO Phase 2 Steps 1–2 production checklist  
**Not in this deploy:** `trip.completed` trigger (Step 4) · €60 lock (Phase 3)

---

## What changed

| Object | Purpose |
|--------|---------|
| `billing_ledger` | Append-only platform fee ledger with per-driver `ledger_sequence` |
| `fn_billing_ledger_assign_sequence` | Assigns monotonic sequence on insert (not balance) |
| `billing_ledger_one_ride_fee_per_ride` | Partial unique index — one `ride_fee` per ride |
| `driver_platform_balance` | View — outstanding balance derived from ledger SUM |
| `market_config` | Hierarchical config (platform → country → city → zone) |
| `fn_get_market_config` | Resolver — most specific scope wins |

---

## Why it changed

- **Accounting-grade trail** for €1/ride platform fees without touching rider fare money.
- **Configuration** decoupled from code — NL defaults (€1 fee, €60 limit) live in DB.
- **Duplicate protection** at DB layer before any automation trigger exists.
- **Balance from ledger** — no cached balance triggers; view is source for reads until Phase 3 lock.

---

## NL market_config verified

| Key | Value |
|-----|-------|
| `platform_fee_cents` | 100 (€1) |
| `outstanding_limit_cents` | 6000 (€60) |
| `currency` | EUR |

---

## Smoke test results

All tests run in a single transaction with `ROLLBACK` — **zero permanent rows**.

| Test | Result |
|------|--------|
| `fn_get_market_config` NL defaults | ✅ PASS |
| Manual `ride_fee` + `ledger_sequence` assigned | ✅ PASS |
| `driver_platform_balance` view | ✅ PASS |
| Reversal append (+100 / -100) | ✅ PASS |
| Duplicate `ride_fee` same ride | ✅ BLOCKED (unique violation) |
| Concurrency (two inserts same ride) | ✅ Exactly one row |
| Performance (1000 inserts + SUM) | ✅ PASS (< 30s threshold) |

**Not yet tested (Step 4 — separate approval):** `trip.completed` → ledger, idempotent retry on double-complete.

**Deferred:** 100k-row perf benchmark on staging before high volume.

---

## Performance impact

- New tables empty at deploy — **no existing query regression**.
- Indexes: `(driver_id, created_at)`, `(driver_id, reason)`, partial unique on `(ride_id, ride_fee)`.
- Balance reads use indexed `driver_id` filter + aggregate — acceptable at launch scale.

---

## Rollback verification

- Script: `scripts/sql/rollback_phase2_billing_ledger_schema.sql`
- Drops: trigger, sequence fn, view, `billing_ledger`, `fn_get_market_config`, `market_config`
- Does **not** touch Phase 1 `ride_audit_log`
- Safe while Step 4 trigger does not exist

---

## New risks introduced

| Risk | Mitigation |
|------|------------|
| No automatic fee on trip complete yet | Step 4 trigger (separate migration) |
| No €60 lock yet | Phase 3 (M10) |
| Sequence trigger race under extreme concurrency | Unique constraints + Step 4 idempotent INSERT |
| Ledger INSERT only via service role today | RLS SELECT-only for drivers; writes via RPC/trigger later |

---

## Future (not V1)

- **Hash chain** per ledger entry for tamper-evident audit (accounting-grade)
- **Cached balance table** only if SUM queries prove too slow at scale

---

## Architecture compliance

| Before | After | Delta |
|--------|-------|-------|
| 57% | **62%** | +5 |

M9 billing ledger: **Partial** (Steps 1–2 live; Step 4 trigger + M10 lock pending)

---

## Next phase

1. Draft Step 4 migration: idempotent `trip.completed` → `ride_fee` ledger entry  
2. Smoke: complete once, complete twice (must still be one fee)  
3. Phase 3: M10 billing lock at €60 in accept/matching  

---

*Signed off: production deploy completed 2026-05-20 per CTO validation checklist.*
