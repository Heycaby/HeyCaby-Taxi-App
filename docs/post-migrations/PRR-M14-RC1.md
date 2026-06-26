# Production Readiness Review — M14 RC1

**Migration:** Program 2 · M14 Presence Foundation  
**Release:** **M14 RC1** (repository approved)  
**Date:** 2026-06-25  
**Status:** 🟡 **PRR complete — awaiting TRB production approval**

| Artifact | Link |
|----------|------|
| Design | [PHASE-4-M14-DESIGN.md](./PHASE-4-M14-DESIGN.md) |
| Architecture gates | [PROGRAM-2-M14-ARCHITECTURE-GATES.md](./PROGRAM-2-M14-ARCHITECTURE-GATES.md) |
| Smoke | [smoke_phase4_m14_presence_foundation.sql](../../scripts/sql/smoke_phase4_m14_presence_foundation.sql) |
| Rollback | [rollback_phase4_m14_presence_foundation.sql](../../scripts/sql/rollback_phase4_m14_presence_foundation.sql) |

## RC status

| Stage | Status |
|-------|--------|
| **M14 RC1** | ✅ Repository + TRB approved |
| **M14 RC2** | ☐ Smoke pass on HEYCABY-TAXI (ROLLBACK) |
| **Production** | ⛔ Blocked — pending this PRR + explicit approval |
| **M14 GA** | ☐ After 48h observation + success metrics |
| **Freeze** | ☐ After GA closure |

---

## 1. Risk — What could break?

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Transition RPC rejects valid driver actions | Low | Medium | M14 expose-only; `connectivity_m14_enabled=false` default |
| Illegal transition bugs block go-online (future Flutter wire) | Low | Medium | Flag off = RPC returns `connectivity_m14_disabled`; legacy path unchanged |
| `platform_health` JSON shape change breaks clients | Low | Low | Additive `connectivity` key only; existing keys unchanged |
| Unique index conflict on concurrent session.start | Low | Low | Prior session closed with `session_replaced` before insert |
| RLS blocks legitimate reads | Low | Low | Driver + admin SELECT policies; writes only via SECURITY DEFINER RPC |
| Migration DDL failure mid-apply | Low | Med | Split M14A–D; apply sequentially; rollback script ready |

**Explicit non-risks (out of scope M14):** dispatch behaviour, billing, accept logic, ride matching — **not modified**.

---

## 2. Blast radius — Who is affected?

| Subsystem | Affected at deploy? | Notes |
|-----------|---------------------|-------|
| **Riders** | **No** | Dispatch unchanged |
| **Drivers** | **No** (until flag on) | `connectivity_m14_enabled=false` — no client calls required |
| **Dispatch** | **No** | `fn_seed_ride_matching_batch` untouched |
| **Billing** | **No** | Ledger / enforcement untouched |
| **Accept** | **No** | M10C unchanged |
| **Admin / support** | Observability only | New views + `platform_health.connectivity` when queried |
| **API errors** | Minimal | New RPCs unused until flag + Flutter |

**Blast radius summary:** **Zero user-visible change** at production deploy with default config.

---

## 3. Detection — How will we know?

| Signal | Source | Alert threshold |
|--------|--------|-----------------|
| Migration apply failure | Supabase MCP / dashboard | Any DDL error |
| Smoke test failure | `smoke_phase4_m14_presence_foundation.sql` | Any RAISE EXCEPTION |
| RPC error rate | Supabase logs / `fn_driver_connectivity_transition` | Spike after flag enabled (future) |
| Illegal transition rate | `driver_connectivity_events` + error responses | > baseline after Flutter wire |
| Legacy drift | `v_connectivity_legacy_drift` | Track count; no action M14 |
| API 5xx on platform_health | App logs | Any increase post-deploy |
| Dispatch regression | `dispatch.batch_seeded` metrics | Unchanged offer rate |

**Primary M14 deploy detection:** smoke pass + no new Postgres errors in 1h post-apply.

---

## 4. Rollback — How quickly can we recover?

| Method | Steps | Est. time |
|--------|-------|-----------|
| **Config (future)** | `connectivity_m14_enabled = false` | **< 1 min** — no redeploy |
| **SQL rollback** | Run `rollback_phase4_m14_presence_foundation.sql` | **5–10 min** — drops tables/RPCs; restores platform_health |
| **Flutter** | Stop calling transition RPC | Immediate (if wired) |

**Rollback tested:** Script in repo; validate in same ROLLBACK transaction as smoke before prod apply.

**Data loss on rollback:** Session/event rows dropped — acceptable for expose phase (no production dependency yet).

---

## 5. Success — Measurable definition

> Deployment succeeded ≠ migration succeeded.

### M14 production deploy success (RC2 → Production)

| Criterion | Target | How measured |
|-----------|--------|--------------|
| DDL applies cleanly | 4/4 migrations | Supabase migration list |
| Smoke tests pass | 6/6 tests | `M14_SMOKE_PASSED` |
| Session creation works | `session.start` → row + event | Smoke Test 1 |
| Events recorded immutably | Append-only; `event_id` unique | Smoke Test 6 dedup |
| Legal transitions only | Illegal rejected | Smoke Test 3 |
| Illegal transitions auditable | Error JSON returned | Smoke Test 3 |
| `platform_health.connectivity` present | Key exists | Smoke Test 5 |
| **No dispatch behaviour change** | skip_metrics unchanged | Compare pre/post dispatch audit |
| **No billing change** | M10A–C RPCs unchanged | Billing smoke still passes |
| **No API error spike** | No increase | Supabase logs 1h window |
| **No rider-facing regression** | N/A — no rider code path | Documented N/A |
| Default flag off | `connectivity_m14_enabled=false` | market_config query |

### M14 GA success (48h observation after production)

| Criterion | Target | How measured |
|-----------|--------|--------------|
| Zero prod incidents tied to M14 | 0 | Support / incident log |
| Drift view queryable | Views return | Manual / admin query |
| RPC latency baseline | p95 < 100ms | Supabase logs (when called) |
| No duplicate authoritative sessions | 0 unresolved | `uq_driver_sessions_authoritative_open` |

---

## 6. Dependencies — What must already exist?

| Dependency | Required? | Notes |
|------------|-----------|-------|
| `market_config` table + `fn_get_market_config` | ✅ | Phase 2 |
| `billing_ledger` + M10A–C live | ✅ | Program 1 LTS — unchanged by M14 |
| `ride_audit_log` + append helpers | ✅ | Phase 1 — optional mirror for transitions |
| `drivers` table | ✅ | Identity only; sessions separate |
| `driver_sessions` | ✅ | Created by M14A (same deploy) |
| `driver_connectivity_events` | ✅ | Created by M14B (same deploy) |
| Supabase Realtime | ☐ Not required at M14 | M15+ transport signals |
| Flutter client wire | ☐ Not required at M14 | Flag off by default |
| Go backend changes | ☐ None | Strangler untouched |

**Order:** M14A → M14B → M14C → M14D (sequential apply). Do not skip.

---

M14 is **Layer 1 — Foundation** (Expose). No Layer 3 Enforcement in this release.

```
Foundation (M14) → Connectivity (M15–17) → Enforcement (M18)
     ↑ RC1/RC2/GA here
```

---

## RC promotion checklist

| Stage | Requirement | Status |
|-------|-------------|--------|
| RC1 | Repo + design + TRB repo review | ✅ |
| RC2 | Smoke pass on HEYCABY-TAXI | ☐ |
| Production | PRR approved + explicit deploy approval | 🟡 PRR ready |
| GA | 48h observation + success metrics above | ☐ |
| LTS | ~30 days post-GA stable | ☐ |
| Freeze | M14 closure doc | ☐ |

---

## TRB sign-off

| Role | Decision | Date |
|------|----------|------|
| TRB — Repository (RC1) | ✅ Approved | 2026-06-25 |
| TRB — PRR | ✅ Complete (this document) | 2026-06-25 |
| TRB — Production deploy | ☐ Pending explicit approval | |
| TRB — GA promotion | ☐ After observation | |

---

*Next step: Apply M14A–D to HEYCABY-TAXI → run smoke → promote to **M14 RC2** → request production approval.*
