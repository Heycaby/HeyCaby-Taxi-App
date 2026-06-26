# Phase 8 — Demand & Performance (complete)

**Scope:** UI/design only — logic, navigation, map rendering, and API contracts unchanged.

**Frozen:** 2026-05-19 · Three demand/performance surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body / overlay widget |
|------|--------------|----------------------|
| `driver_score_screen.dart` | Performance Scorecard | `DriverPerformanceScorecardBody` |
| `driver_tariff_editor_screen.dart` | Rate Control | `DriverRateControlBody` |
| `driver_hotspots_screen.dart` | Demand Radar | `DriverDemandRadarOverlay` (map logic stays in screen) |

Shared components in `driver_performance_flow_common.dart`: scaffold, info banners, sub-score rows, comment cards, best-zone card, tariff preset banner, map overlay chrome.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `performance_scorecard_light.png` | Performance Scorecard |
| `rate_control_light.png` | Rate Control |
| `demand_radar_light.png` | Demand Radar (overlay chrome; map stubbed in test) |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-8-performance ./scripts/driver_visual_regression.sh gallery
```

---

## Next

**Phase 9+** — community, human chat, manual ride entry, indemnification per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
