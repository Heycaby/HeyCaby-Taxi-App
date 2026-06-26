# Phase 3 M10B Post-Migration Report — Dispatch Billing Filter

**Date:** 2026-05-20  
**Project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`)  
**Migrations:** `v1_phase3_m10b_dispatch_billing_filter`, `v1_phase3_m10b_seed_select_fix`  
**Approval:** CTO M10B production

---

## What changed

| Change | Behaviour |
|--------|-----------|
| `fn_seed_ride_matching_batch` | Skips billing-LOCKED drivers before invite |
| `skip_metrics` | Per-batch counts (billing, busy, offline, eligible, …) |
| `dispatch.batch_seeded` | Audit event with metrics + `dispatch_version: 1` |
| `dispatch_duration_ms` | Batch timing for perf monitoring |
| `SELECT * INTO v_ride` fix | Correct row assignment (prod hotfix same deploy) |

**Unchanged:** `fn_driver_accept_ride_invite` — no hard reject yet (M10C).

---

## Why it changed

Soft enforcement: locked drivers never receive offers (better UX than accept-time reject). Skip metrics explain *why* riders wait.

---

## Smoke tests (ROLLBACK)

| # | Test | Result |
|---|------|--------|
| 2 | Closest locked → next eligible + version/duration | ✅ |
| 5 | Near locked / far GOOD → far invited | ✅ |

(Full script: `scripts/sql/smoke_phase3_m10b_dispatch_billing_filter.sql`)

---

## Backward compatibility

| Check | Result |
|-------|--------|
| Accept RPC | ✅ No billing lock |
| Flutter contract | ✅ Unchanged — apps ignore new JSON fields |
| Rider UX | ✅ Invites continue to eligible drivers |

---

## Post-deploy monitoring (CTO checklist)

Observe first real dispatches:

- [ ] Eligible drivers still receive offers
- [ ] No abnormal rider wait times
- [ ] `skip_metrics` match driver states
- [ ] No spike in unmatched rides

Query:

```sql
SELECT metadata->'skip_metrics', occurred_at
FROM ride_audit_log
WHERE event = 'dispatch.batch_seeded'
ORDER BY occurred_at DESC LIMIT 20;
```

---

## Performance

`dispatch_duration_ms` captured per batch — baseline TBD at pre-launch volume.

---

## Rollback

`scripts/sql/rollback_phase3_m10b_dispatch_billing_filter.sql` → re-apply `20260403140000_favorites_first_matching.sql` seed fn.

---

## Architecture compliance

| Before | After | Delta |
|--------|-------|-------|
| 72% | **77%** | +5 |

---

## Next

**M10C** — hard accept enforcement + `billing.accept_blocked` + `dispatch.driver_rejected_billing` (repo ready, separate approval).

After M10C: shift focus to presence/heartbeat, dispatch waves, Go strangler — not more billing.

---

*M10B live 2026-05-20. M10A frozen.*
