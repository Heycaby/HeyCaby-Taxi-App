# Phase 9 — Trust & Feedback (complete)

**Scope:** UI/design only — logic, navigation, API contracts, and consent dialogs unchanged.

**Frozen:** 2026-05-19 · Four trust/feedback surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `rate_rider_screen.dart` | Feedback Loop | `DriverFeedbackLoopBody` |
| `driver_terms_screen.dart` | Terms Trust | `DriverLegalTrustBody` |
| `driver_privacy_screen.dart` | Privacy Trust | `DriverLegalTrustBody` |
| `support_lee_screen.dart` | AI Support Chat | `DriverAiSupportChatBody` |

Shared components in `driver_trust_flow_common.dart`: scaffold, legal language toolbar, section cards, chat bubbles, composer bar, empty state.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `feedback_loop_light.png` | Feedback Loop (post-ride rating) |
| `legal_trust_light.png` | Terms Trust |
| `privacy_trust_light.png` | Privacy Trust |
| `ai_support_chat_light.png` | AI Support Chat (Lee) |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-9-trust ./scripts/driver_visual_regression.sh gallery
```

---

## Deferred (Phase 10+)

- `support_chat_screen.dart` — human support thread UI
- `driver_indemnification_screen.dart` — liability acknowledgment
- `driver_community_hub_screen.dart` / `driver_community_channel_feed_screen.dart` — community surfaces
- `driver_add_manual_ride_screen.dart` — manual ride entry form

---

## Next

**Phase 10+** — manual ride entry, return trips, remaining ride-adjacent screens per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
