# Phase 1 Post-Migration Report

**Date:** 2026-05-20  
**Migration:** `v1_phase1_ride_audit_log_and_rls`  
**Tracker:** M8, M25  
**Compliance:** 52% → 57%

---

## What changed

| Component | Change |
|-----------|--------|
| `ride_audit_log` | New insert-only table for dispatch + lifecycle events |
| Triggers | `trg_ride_audit_ride_requests`, `trg_ride_audit_invites` |
| `fn_ride_audit_append` | SECURITY DEFINER helper for append-only writes |
| `launch_regions` | RLS enabled; SELECT for anon/authenticated |
| `founding_contract_links` | RLS enabled; no client policies (deny by default) |

---

## Why it changed

- **M8:** Support and disputes need a single timeline (`ride.created`, `offer.*`, `ride.cancelled`, etc.) without guessing from scattered triggers.
- **M25:** Security advisor flagged exposed tables; deny-by-default on sensitive founding contract tokens.

---

## Smoke test results

| Test | Result |
|------|--------|
| Insert `ride_requests` → `ride.created` | ✅ Pass |
| Status → `cancelled` → multiple audit rows | ✅ Pass (≥3 events) |
| Cleanup (delete test ride) | ✅ Pass |
| Triggers present in `pg_trigger` | ✅ Verified |

---

## Performance impact

- **Low.** Append-only inserts on ride/invite mutations; two indexes on `ride_audit_log`.
- No change to accept RPC hot path logic.
- Existing ride volume tiny (46 requests); no measurable latency change expected.

---

## Rollback verification

| Action | Effect |
|--------|--------|
| Drop triggers | Audit stops; apps unchanged |
| Drop `ride_audit_log` | Loses forward audit only (table new, empty history for old rides) |
| Disable RLS on `launch_regions` | Reverts to pre-Phase-1 exposure model — not recommended |

Rollback tested conceptually; no production rollback required.

---

## New risks introduced

| Risk | Mitigation |
|------|------------|
| Audit rows CASCADE-delete with ride | Acceptable for V1; consider soft-link later if rides must be deleted |
| Trigger overhead on high write volume | Monitor; negligible at launch scale |
| `founding_contract_links` deny-all | Edge Functions must use service role (already expected) |

---

## Follow-up (Phase 1.5 — shipped 2026-05-20)

- Added `correlation_id`, `actor_type`, `source` to audit rows (live on HEYCABY-TAXI).
- Query all events for one ride: `WHERE correlation_id = '<ride_uuid>'`.

---

*Next: Phase 2 billing ledger Steps 1–2 — design in repo; production pending explicit approval.*
