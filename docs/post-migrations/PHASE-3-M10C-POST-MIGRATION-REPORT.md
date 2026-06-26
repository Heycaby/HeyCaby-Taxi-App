# Phase 3 M10C Post-Migration Report — Accept Billing Enforcement

**Date:** 2026-06-25  
**Project:** HEYCABY-TAXI (`fvrprxguoternoxnyhoj`)  
**Migrations:** `v1_phase3_m10c_accept_billing_enforcement`, `v1_phase3_m10c_accept_status_fix`  
**Approval:** CTO M10C production (feature flag + grace + E2E smoke)

---

## What changed

| Change | Behaviour |
|--------|-----------|
| `market_config` NL | `billing_enforcement: true`, `billing_grace_period_minutes: 0` |
| `fn_driver_can_accept_rides` | Reads enforcement flag + grace; returns observability fields |
| `fn_driver_accept_ride_invite` | Blocks when `allowed: false`; dual audit on reject |
| Accept status hotfix | Sets `accepted` (not `assigned`) — matches DB check constraint |

**Control point:** `billing_enforcement=false` in `market_config` disables block for M10B dispatch filter **and** M10C accept — no redeploy.

**Grace:** When `billing_grace_period_minutes > 0`, LOCKED drivers within grace window of latest `billing.limit_reached` event get `status: GRACE`, `allowed: true`.

---

## Why it changed

First migration that actively tells a driver **no** at accept time. CTO required config-driven rollout and full lifecycle validation before declaring billing complete.

---

## Smoke tests (ROLLBACK — all passed on prod)

| # | Scenario | Result |
|---|----------|--------|
| 0 | `billing_enforcement=false` + €61 outstanding → still allowed | ✅ |
| 1 | €61 → settlement → immediate `allowed: true` | ✅ |
| 2 | Valid invite + balance crosses limit → `billing_locked` + dual audit | ✅ |
| 3 | **E2E:** €59 → complete ride → €60 → accept blocked → pay → accept succeeds | ✅ |

Script: `scripts/sql/smoke_phase3_m10c_accept_billing_enforcement.sql`

---

## Production hotfix (same deploy)

E2E smoke caught pre-existing bug: accept RPC used `status = 'assigned'` but `ride_requests_status_check` only allows `accepted`. Fixed in `v1_phase3_m10c_accept_status_fix`.

---

## Emergency rollback (no code deploy)

```sql
UPDATE public.market_config
SET config_value = 'false'::jsonb
WHERE scope = 'country' AND country_code = 'NL'
  AND config_key = 'billing_enforcement' AND active = true;
```

Full function rollback: `scripts/sql/rollback_phase3_m10c_accept_billing_enforcement.sql`

---

## Post-deploy monitoring (CTO observation window)

Watch for 48–72h at pre-launch volume:

- [ ] No unexpected spike in `billing.accept_blocked` vs locked driver count
- [ ] No increase in unmatched rides / dispatch failures
- [ ] Payment → immediate accept recovery in support tickets (should be zero)

```sql
-- Blocked accepts (last 24h)
SELECT COUNT(*), date_trunc('hour', occurred_at) AS hour
FROM billing_audit_log
WHERE event = 'billing.accept_blocked'
  AND occurred_at > now() - interval '24 hours'
GROUP BY 1 ORDER BY 2;

-- Enforcement config (verify)
SELECT config_key, config_value FROM market_config
WHERE country_code = 'NL' AND config_key LIKE 'billing_%' AND active;
```

---

## Backward compatibility

| Check | Result |
|-------|--------|
| Flag off | ✅ Locked drivers can accept (emergency path) |
| M10A/M10B | ✅ Frozen — M10C extends `fn_driver_can_accept_rides` only |
| Flutter | N/A this deploy — accept RPC contract adds `billing_locked` error; apps should map when wired |
| Go backend | ✅ Unchanged — strangler not touched |

---

## Architecture compliance

| Before | After | Delta |
|--------|-------|-------|
| 77% | **82%** | +5 |

---

## Billing Program — ✅ Complete

Foundational billing work is **closed**. Future billing work = bug fixes, performance, new business features only.

**Next engineering program:** Presence · Dispatch waves · Go strangler (one endpoint at a time).

---

*M10C live 2026-06-25. M10A + M10B frozen.*
