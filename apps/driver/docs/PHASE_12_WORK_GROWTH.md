# Phase 12 — Work & Growth (complete)

**Scope:** UI/design only — ride swap feed logic, go-online policy, referral share, and suggestion submission unchanged.

**Frozen:** 2026-05-19 · Four work/growth surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `ride_swap_screen.dart` | Ride Swap | `DriverRideSwapBody` |
| `go_online_screen.dart` | Go Live | `DriverGoLiveBody` |
| `driver_tell_friend_screen.dart` | Referral Share | `DriverReferralShareBody` |
| `driver_app_suggestion_screen.dart` | App Suggestion | `DriverAppSuggestionBody` |

Shared components in `driver_work_flow_common.dart`: scaffold, go-live readiness cards, ride swap offer cards, suggestion idea cards, referral link card.

Helper: `driverSuggestionIdeaFromStatus()` in `driver_app_suggestion_body.dart` maps backend status → display chip.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `ride_swap_light.png` | Ride Swap |
| `go_live_light.png` | Go Live |
| `referral_share_light.png` | Referral Share |
| `app_suggestion_light.png` | App Suggestion |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-12-work-growth ./scripts/driver_visual_regression.sh gallery
```

---

## Deferred (Phase 13+)

- `splash_screen.dart` — Brand Moment
- Remaining secondary screens from blueprint

---

## Next

**Phase 13+** — entry gates, work hub, remaining screens per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
