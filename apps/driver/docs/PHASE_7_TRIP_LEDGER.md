# Phase 7 — Trip Ledger (complete)

**Scope:** UI/design only — logic, navigation, API contracts, and data fetching unchanged.

**Frozen:** 2026-05-19 · Three trip ledger screens redesigned using Phase 2 kit + ledger shell.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `today_rides_screen.dart` | Today's Ledger | `DriverTodaysLedgerBody` |
| `driver_my_rides_screen.dart` | Ride History | `DriverRideHistoryBody` |
| `driver_ride_detail_screen.dart` | Trip Receipt | `DriverTripReceiptBody` |

Shared components: `DriverLedgerFlowScaffold`, `DriverLedgerCompactRow`, `DriverLedgerReceiptHero`, `DriverLedgerDetailList` in `driver_ledger_flow_common.dart`. Reuses `DriverRideCard` and `DriverMoneyKeyValueRow`.

`driver_add_manual_ride_screen.dart` (Manual Entry) remains legacy layout — Phase 8+.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `todays_ledger_light.png` | Today's Ledger |
| `ride_history_light.png` | Ride History |
| `trip_receipt_light.png` | Trip Receipt |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-7-ledger ./scripts/driver_visual_regression.sh gallery
```

---

## Next

**Phase 9+** — community, chat polish, manual ride entry, legal screens per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
