# Phase 3 — Core Ride Flow (complete)

**Scope:** UI/design only — logic, navigation, and backend contracts unchanged.

**Frozen:** 2026-05-19 · Five ride-flow screens redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `new_ride_request_screen.dart` | Opportunity Screen | `DriverOpportunityScreenBody` |
| `active_ride_screen.dart` | Active Trip | `DriverActiveTripBody` |
| `at_pickup_screen.dart` | Pickup Arrival | `DriverPickupArrivalBody` |
| `ride_in_progress_screen.dart` | Navigation Focus | `DriverNavigationFocusBody` |
| `ride_complete_screen.dart` | Reward Screen | `DriverRewardScreenBody` |

Shared shell: `DriverRideFlowScaffold`, `DriverRideTripSummary`, `DriverRideActionGrid`, `DriverRideFlowBottomBar` in `driver_ride_flow_common.dart`.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `ride_request_light.png` | Opportunity |
| `active_trip_light.png` | Active Trip |
| `pickup_arrival_light.png` | Pickup Arrival |
| `navigation_focus_light.png` | Navigation Focus |
| `reward_screen_light.png` | Reward |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-3-ride ./scripts/driver_visual_regression.sh gallery
```

---

## Next

**Phase 4 — Money & Earnings** per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).

Not in Phase 3 scope: `rate_rider_screen.dart` (completion follow-up — Phase 4 or later).
