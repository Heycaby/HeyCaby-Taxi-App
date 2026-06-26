# Phase 3 M10C Design — Accept Billing Enforcement

**Status:** Design approved · **Production gated on two smokes**  
**Prerequisite:** M10A ✅ frozen · M10B ✅ frozen

---

## What M10C changes (first user-visible billing behaviour)

`fn_driver_accept_ride_invite` checks **`fn_driver_can_accept_rides()` at accept time** — not at invite time.

| Result | Response |
|--------|----------|
| LOCKED | `{ ok: false, error: "billing_locked", message: "..." }` |
| GOOD/WARNING | Normal accept flow |

---

## Dual audit on reject

| Event | Table |
|-------|-------|
| `billing.accept_blocked` | `billing_audit_log` |
| `dispatch.driver_rejected_billing` | `ride_audit_log` |

---

## CTO validations required before prod

| # | Scenario | Script |
|---|----------|--------|
| 1 | **Payment recovery** — €61 → settlement → `allowed: true` immediately (no cron/cache) | `smoke_phase3_m10c` Test 1 |
| 2 | **Accept-time race** — valid invite + balance crosses €60 before accept → reject + dual audit | `smoke_phase3_m10c` Test 2 |

---

## After M10C

**Billing subsystem complete.** Engineering focus shifts to:

- Presence / heartbeat (M14–M15)
- Dispatch waves + offer expiry (M4–M7)
- Go strangler (M12–M23)
- Not more billing

---

## Approval gate

> **Approve Phase 3 M10C production**

After both smokes pass on HEYCABY-TAXI + post-migration report.

---

## Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260520190000_v1_phase3_m10c_accept_billing_enforcement.sql` | M10C SQL |
| `scripts/sql/smoke_phase3_m10c_accept_billing_enforcement.sql` | Two CTO tests |
| `scripts/sql/rollback_phase3_m10c_accept_billing_enforcement.sql` | Rollback pointer |
