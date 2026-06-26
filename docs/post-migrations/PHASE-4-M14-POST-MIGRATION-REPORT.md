# M14 Post-Migration Report

**Project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`)  
**Date:** 2026-05-19  
**Stage:** Production deploy → M14 RC2 → 48h observation  
**User impact:** None (`connectivity_m14_enabled = false`)

---

## Deployed

| Migration | Objects |
|-----------|---------|
| `v1_phase4_m14a_driver_sessions` | `driver_sessions`, RLS, market_config keys |
| `v1_phase4_m14b_driver_connectivity_events` | `driver_connectivity_events`, RLS |
| `v1_phase4_m14c_connectivity_transition_rpc` | Helper fns (`fn_connectivity_*_target`, `fn_connectivity_m14_enabled`) |
| `v1_phase4_m14c_driver_connectivity_rpc_fns` | `fn_driver_connectivity_transition`, `fn_driver_session_current`, `fn_driver_connectivity_summary` |
| `v1_phase4_m14d_connectivity_observability` | Views + `fn_driver_platform_health` connectivity section |

**Note:** M14C applied as two prod migration records (helper fns first, main RPCs second). Repo file `20260625120200_v1_phase4_m14c_connectivity_transition_rpc.sql` is the canonical single source.

---

## Hotfix during deploy

`v_connectivity_legacy_drift` failed on first apply: `drivers.status` is enum `driver_status`, not `text`. Fixed with `d.status::text` casts in view and `fn_driver_platform_health`. Repo M14D updated to match.

---

## Smoke test

**Script:** `scripts/sql/smoke_phase4_m14_presence_foundation.sql`  
**Result:** `M14_SMOKE_PASSED` (ROLLBACK transaction on prod)

| Test | Assertion |
|------|-----------|
| 1 | `session.start` → presence `present` |
| 2 | `go_available` / `go_offline` operational transitions |
| 3 | `busy → go_offline` rejected (`illegal_transition`) |
| 4 | `session.end` closes session |
| 5 | `fn_driver_platform_health` includes `connectivity` |
| 6 | `event_id` deduplication |

---

## Config verification

```sql
connectivity_m14_enabled = false   -- NL, active
connectivity_state_machine_version = 1
```

Dispatch, billing, accept, and ride matching **unchanged**.

---

## Observation window (48h) — active

**CTO decision (2026-05-19):** M14 RC2 approved. Observe only — no M15, no features, no optimization until ~2026-05-21.

### Day-0 baseline (2026-05-19)

| Metric | Value |
|--------|-------|
| `driver_sessions` | 0 |
| `driver_connectivity_events` | 0 |
| `v_connectivity_active_sessions` | 0 |
| `v_connectivity_legacy_drift` | 4 rows (expected: no sessions yet; legacy `drivers.status` vs NULL session operational) |
| `connectivity_m14_enabled` | `false` |

### Database

- New SQL errors, RPC failures, trigger failures (Supabase logs / advisors)

### Connectivity

```sql
SELECT COUNT(*) FROM public.driver_sessions;
SELECT COUNT(*) FROM public.driver_connectivity_events;
SELECT * FROM public.v_connectivity_event_rates ORDER BY hour DESC LIMIT 24;
```

Sessions/events should stay ~0 while flag is off.

### Drift baseline

```sql
SELECT COUNT(*) AS drift_rows FROM public.v_connectivity_legacy_drift;
SELECT * FROM public.v_connectivity_legacy_drift LIMIT 20;
```

Capture count now — baseline before enabling connectivity.

### Performance

- RPC latency on `fn_driver_connectivity_transition` (when exercised)
- Query time on observability views
- Realtime latency (unchanged by M14; watch for regression)

### Regression (stop immediately if any change)

- Dispatch unchanged
- Billing unchanged
- Ride acceptance unchanged

**Promote path:** Clean 48h → **M14 GA** → **30d stable** → **M14 LTS / Freeze** → **M15 Heartbeat**.

### Future (not during observation)

- **Program 2 dashboard:** sessions active, heartbeat success, reconnect, duplicate/stale sessions, false offline, truth accuracy (build when M15+ starts)
- **Chaos test:** schedule after M17 (app kill, airplane mode, tunnel, duplicate login, etc.)

---

## Rollback

`scripts/sql/rollback_phase4_m14_presence_foundation.sql` (test on staging before any prod rollback).

---

*Execution artifact. Architecture: [PHASE-4-M14-DESIGN.md](./PHASE-4-M14-DESIGN.md) (frozen).*
