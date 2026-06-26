# Billing Program Closure

**Date:** 2026-06-25  
**Status:** ✅ **Complete**

---

## Scope delivered (Phases 1–3)

| Layer | Migration | Capability |
|-------|-----------|------------|
| Audit | M8, M25 | Immutable ride timeline + RLS |
| Ledger | M9 | Append-only billing_ledger + trip.completed accrual |
| Eligibility | M10A | Derived status, can_accept, platform_health |
| Dispatch filter | M10B | Skip locked drivers + skip_metrics |
| Accept enforcement | M10C | Hard reject + config flag + grace |

## Engineering principle (permanent)

> **Every new business rule must first exist as an observable capability before it becomes an enforced rule.**

```
Expose → Observe → Measure → Enforce
```

Applied across M10A (expose) → M10B (measure dispatch) → M10C (enforce accept).

## What billing receives going forward

- Bug fixes
- Performance improvements
- New business features (e.g. settlement RPC M11)

**Not:** foundational schema or enforcement layering.

## Emergency controls (live)

| Control | Key | NL launch |
|---------|-----|-----------|
| Disable enforcement | `market_config.billing_enforcement` | `true` |
| Grace period | `market_config.billing_grace_period_minutes` | `0` |

Set `billing_enforcement` to `false` to rollback behaviour without code deploy.

---

**Next:** [HEYCABY-MASTER-TRACKER.md](../../HEYCABY-MASTER-TRACKER.md) — Program 2 (Driver Connectivity)
