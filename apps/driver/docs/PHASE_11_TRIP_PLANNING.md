# Phase 11 — Trip Planning (complete)

**Scope:** UI/design only — geocoding, API calls, realtime subscriptions, and swap dialogs unchanged.

**Frozen:** 2026-05-19 · Three trip-planning surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `driver_add_manual_ride_screen.dart` | Manual Ride Entry | `DriverManualRideEntryBody` |
| `driver_return_trips_screen.dart` | Return Trips | `DriverReturnTripsBody` |
| `scheduled_rides_screen.dart` | Scheduled Rides | `DriverScheduledRidesBody` |

Shared components in `driver_trip_planning_flow_common.dart`: scaffold, section cards, return discount card, return offer card, scheduled tab bar, scheduled ride card, geocoding suggestion tile.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `manual_ride_entry_light.png` | Manual Ride Entry |
| `return_trips_light.png` | Return Trips |
| `scheduled_rides_light.png` | Scheduled Rides |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-11-planning ./scripts/driver_visual_regression.sh gallery
```

---

## Deferred (Phase 12+)

- Community hub modals (search, notifications)
- Remaining secondary screens from blueprint

---

## Next

**Phase 12+** — ride swap, work/go-online polish, remaining screens per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
