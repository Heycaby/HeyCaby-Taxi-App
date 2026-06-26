# Phase 3 Design — Billing Eligibility & Enforcement

**Status:** Design approved · **Production NOT approved**  
**Prerequisite:** Phase 2 closed ✅ (M9 live)  
**CTO decision:** Derived state only — **no stored `billing_status` column**

---

## Core principle

```text
outstanding = SUM(billing_ledger)
limit       = fn_get_market_config('outstanding_limit_cents', …)
status      = fn_billing_derive_status(outstanding, limit)   -- computed at read time
```

Payment or reversal changes ledger → status updates **immediately** with no sync triggers on a cached column.

If performance requires it later: materialized view or cache — not V1.

---

## Three independent migrations

| ID | File | Behaviour | Enforces? |
|----|------|-----------|-----------|
| **M10A** | `20260520170000_v1_phase3_m10a_billing_eligibility.sql` | RPCs + `billing_audit_log` | No |
| **M10B** | `20260520180000_v1_phase3_m10b_dispatch_billing_filter.sql` | Skip locked drivers in matching | Soft (no invite) |
| **M10C** | `20260520190000_v1_phase3_m10c_accept_billing_enforcement.sql` | Reject accept when locked | Hard |

Deploy order: **M10A → smoke → M10B → smoke → M10C → smoke** (each needs explicit prod approval).

---

## RPCs (M10A)

### `fn_driver_can_accept_rides(driver_id?)`

```json
{
  "allowed": false,
  "reason": "Outstanding platform fees exceed market limit.",
  "status": "LOCKED",
  "outstanding_cents": 6100,
  "limit_cents": 6000,
  "remaining_cents": 0,
  "currency": "EUR",
  "country_code": "NL"
}
```

### `fn_driver_platform_health()` — Driver Readiness API (permanent)

Long-term single RPC for Go Online + admin dashboard. M10A returns billing, driver, dispatch; future sections: verification, heartbeat, market (see CTO roadmap).

---

```json
{
  "allowed": true,
  "billing": { "status": "GOOD", "outstanding": 1200, "limit": 6000, "remaining": 4800, "currency": "EUR", "can_accept_rides": true },
  "driver": { "verified": true, "documents_valid": true, "vehicle_approved": true, "is_online": false },
  "dispatch": { "eligible": false }
}
```

Authenticated drivers: own row only. Admins: any driver. Service role: explicit `driver_id` for ops/smoke.

### `fn_driver_billing_summary(driver_id?)`

Dashboard-focused subset: outstanding, limit, remaining, currency, status, platform_fee_cents.

---

## M10C audit (repo — not prod)

On billing reject writes **both**:

- `billing.accept_blocked` → `billing_audit_log`
- `dispatch.driver_rejected_billing` → `ride_audit_log`

---

## Derived status rules

| Status | Condition (NL example) |
|--------|------------------------|
| `GOOD` | outstanding < 4800 |
| `WARNING` | outstanding ≥ 4800 and < 6000 |
| `LOCKED` | outstanding ≥ 6000 |

---

## billing_audit_log namespace

| Event | When |
|-------|------|
| `billing.ride_fee_created` | Also in `ride_audit_log` (Step 4) |
| `billing.limit_reached` | First accrual crossing into LOCKED |
| `billing.accept_blocked` | M10C reject |
| `billing.reversal_created` | Future admin RPC |
| `billing.payment_received` | Future settlement RPC |
| `billing.unlocked` | Future when crossing back below limit |

---

## M10B — Dispatch

`fn_seed_ride_matching_batch` adds billing filter + **skip_metrics** in response and `dispatch.batch_seeded` audit event.

### Skip metrics (per batch)

```json
{
  "candidates_with_location": 12,
  "skipped_billing_locked": 2,
  "skipped_busy": 1,
  "skipped_offline": 3,
  "skipped_vehicle": 0,
  "skipped_pet": 0,
  "skipped_already_invited": 0,
  "eligible": 6,
  "invited": 4,
  "batch_size": 4
}
```

One **primary** skip reason per driver (priority: already_invited → busy → offline → billing → vehicle → pet → eligible).

### CTO validations before prod

| # | Validation | Script |
|---|------------|--------|
| 1 | Billing invite matrix (€0–€75) | `smoke_phase3_m10b_dispatch_billing_filter.sql` Test 1 |
| 2 | Closest locked → next eligible + metrics | Test 2 |
| 3 | 2 locked / 3 eligible → offers still sent | Test 3 |
| 4 | `dispatch.batch_seeded` in ride_audit_log | Test 4 |

### Future: dispatch decision log

Full per-ride candidate breakdown (radius, billing, availability) — Phase 4+ extension of audit strategy.

### Dispatch quality metrics (track after M10B prod)

- Dispatch success rate
- Average offer / acceptance time
- Drivers skipped by billing / busy / offline

---

## M10C — Accept

`fn_driver_accept_ride_invite` checks `fn_driver_can_accept_rides` before assign:

```json
{ "ok": false, "error": "billing_locked", "message": "Outstanding platform fees exceed market limit." }
```

Writes `billing.accept_blocked` to `billing_audit_log`.

---

## Smoke tests

| Migration | Script |
|-----------|--------|
| M10A | `scripts/sql/smoke_phase3_m10a_billing_eligibility.sql` |
| M10B | Manual: locked driver excluded from batch insert |
| M10C | Manual: accept returns `billing_locked` |

---

## Rollback

| Migration | Script |
|-----------|--------|
| M10A | `scripts/sql/rollback_phase3_m10a_billing_eligibility.sql` |
| M10B | Re-apply `20260403140000_favorites_first_matching.sql` seed fn |
| M10C | Restore accept fn from `20260329180000_ride_matching_cascade.sql` |

---

## Go / Flutter

- **Do not touch Go** until Supabase billing + dispatch stable.
- Flutter: wire `fn_driver_billing_summary` when building billing UI (optional before M10C prod).

---

## Approval gate

> **Approve Phase 3 M10A production**

Then M10B, then M10C — each with post-migration report + tracker update.

**Do not batch all three in one deploy.**
