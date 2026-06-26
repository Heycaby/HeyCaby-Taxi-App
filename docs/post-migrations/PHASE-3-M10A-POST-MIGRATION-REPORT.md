# Phase 3 M10A Post-Migration Report — Billing Eligibility

**Date:** 2026-05-20  
**Project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`)  
**Migrations applied:** `v1_phase3_m10a_billing_eligibility` (+ function parts + auth fix)  
**Approval:** CTO M10A production + user proceed

---

## What changed

| Object | Purpose |
|--------|---------|
| `billing_audit_log` | Support timeline (`billing.*` events) |
| `fn_billing_driver_outstanding_cents` | `SUM(ledger)` — source of truth |
| `fn_billing_derive_status` | GOOD / WARNING / LOCKED (computed, **not stored**) |
| `fn_driver_can_accept_rides` | Eligibility JSON — **expose only, no enforcement** |
| `fn_driver_billing_summary` | Flutter/admin dashboard RPC |
| `fn_driver_platform_health` | Unified readiness (billing + driver + dispatch) |
| `fn_billing_accrue_ride_fee` | + `billing.limit_reached` on first cross into LOCKED |

**Not changed (backward compatibility):**

| Function | Status |
|----------|--------|
| `fn_driver_accept_ride_invite` | Unchanged — no billing block yet (M10C) |
| `fn_seed_ride_matching_batch` | Unchanged — no billing filter yet (M10B) |

---

## Why it changed

- Expose billing eligibility server-side before enforcement.
- Single RPCs for Flutter/admin — no client-side billing math.
- Derived status: pay down ledger → status updates instantly, no sync column.

---

## Smoke test results (ROLLBACK)

| Test | Result |
|------|--------|
| Zero outstanding → GOOD, allowed | ✅ |
| 6100 cents → LOCKED, not allowed | ✅ |
| `fn_driver_platform_health` shape | ✅ |
| Settlement paydown → GOOD again | ✅ |

---

## Backward compatibility (App Store)

| Check | Result |
|-------|--------|
| Existing accept RPC signature/behaviour | ✅ Unchanged |
| Existing dispatch matching | ✅ Unchanged |
| New RPCs called from Flutter/Go in repo | ✅ **None** — no app update required |
| Trip completion → fee accrual | ✅ Same + optional `limit_reached` audit |
| Rider app RPCs | ✅ Unaffected |

Shipped app versions continue to work. New RPCs are opt-in when Flutter wires billing UI.

---

## Performance impact

- New RPCs are on-demand reads with indexed `billing_ledger.driver_id` SUM.
- Pre-launch volume: negligible.
- No new triggers on hot paths except extended accrue fn (one extra SUM on new fees).

---

## Rollback

`scripts/sql/rollback_phase3_m10a_billing_eligibility.sql`

---

## Architecture compliance

| Before | After | Delta |
|--------|-------|-------|
| 67% | **72%** | +5 |

---

## Next

**Request approval for M10B** (dispatch soft filter) — separate migration, smoke, report.

M10C adds `dispatch.driver_rejected_billing` to `ride_audit_log` (already in repo).

---

*M10A live 2026-05-20. Phase 2 remains frozen.*
