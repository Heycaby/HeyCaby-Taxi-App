# Phase 4 — Money & Earnings (complete)

**Scope:** UI/design only — logic, navigation, API contracts, and billing flows unchanged.

**Frozen:** 2026-05-19 · Three money screens redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `driver_finance_screen.dart` | Earnings Hub | `DriverEarningsHubBody` |
| `driver_billing_screen.dart` | Subscription Gate | `DriverSubscriptionGateBody` |
| `driver_billing_history_screen.dart` | Payment History | `DriverPaymentHistoryBody` |

Shared shell: `DriverMoneyFlowScaffold`, `DriverMoneyKeyValueRow`, `DriverFinanceExportSheet` in `driver_money_flow_common.dart`.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `earnings_hub_light.png` | Earnings Hub |
| `subscription_gate_light.png` | Subscription Gate |
| `payment_history_light.png` | Payment History |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-4-money ./scripts/driver_visual_regression.sh gallery
```

---

## Next

**Phase 5 — Settings & Profile** per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).

Trip ledger screens (`today_rides_screen`, `driver_my_rides_screen`, etc.) remain Phase 5+ unless pulled forward.
