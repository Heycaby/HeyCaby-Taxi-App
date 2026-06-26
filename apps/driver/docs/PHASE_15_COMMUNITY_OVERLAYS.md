# Phase 15 — Community Overlays & Staging (complete)

**Scope:** UI/design only — notification providers, search API, disclaimer persistence, and post submission unchanged.

**Frozen:** 2026-05-19 · Community hub modals/sheets extracted + staging surface on kit.

---

## Surfaces

| File | Purpose name | Body / overlay widget |
|------|--------------|----------------------|
| `driver_community_hub_screen.dart` | Community Hub (modals) | `DriverCommunityNotificationsSheetBody`, `DriverCommunitySearchSheetBody`, `DriverCommunityDisclaimerBody`, `DriverCommunityNotificationDetailBody` |
| `driver_community_create_post_sheet.dart` | Create Post sheet | `DriverCommunityCreatePostBody` |
| `placeholder_screen.dart` | Staging Surface | `DriverStagingSurfaceBody` |

Shared: `driver_community_overlay_bodies.dart` — tiles, search rows, disclaimer sections, `show*` helpers.

---

## Visual regression

| Golden | Surface |
|--------|---------|
| `community_notifications_light.png` | Notifications sheet |
| `community_search_light.png` | Search sheet |
| `community_disclaimer_light.png` | Welcome disclaimer dialog |
| `community_create_post_light.png` | Create post sheet |
| `staging_surface_light.png` | Staging placeholder |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-15-overlays ./scripts/driver_visual_regression.sh gallery
```

---

## Redesign program status

All **51 registered screens** plus community overlay surfaces now use Phase 2 kit body widgets or shared flow scaffolds. Remaining work is product/feature — not layout debt.

---

## Next

Blueprint complete for driver UI redesign. Future changes: extend kit components only when a pattern appears twice.
