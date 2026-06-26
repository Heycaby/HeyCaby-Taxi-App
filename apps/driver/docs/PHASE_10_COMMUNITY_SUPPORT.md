# Phase 10 — Community & Support Conversation (complete)

**Scope:** UI/design only — logic, navigation, API contracts, and modals unchanged.

**Frozen:** 2026-05-19 · Four community and support surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `driver_community_hub_screen.dart` | Community Hub | `DriverCommunityHubBody` |
| `driver_community_channel_feed_screen.dart` | Community Channel | `DriverCommunityChannelBody` |
| `support_chat_screen.dart` | Support Conversation | `DriverSupportConversationBody` |
| `driver_indemnification_screen.dart` | Liability Acknowledgment | `DriverLiabilityAcknowledgmentBody` |

Shared components in `driver_community_flow_common.dart`: hub header, feed selector, section badge, extended FAB, channel scaffold.

Post rows still use existing `TalkRow` / `driver_community_hub_parts.dart` — feed content stays wired from screen logic.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `community_hub_light.png` | Community Hub (trending preview) |
| `community_channel_light.png` | Community Channel (driver talk) |
| `support_conversation_light.png` | Support Conversation (open ticket) |
| `liability_ack_light.png` | Liability Acknowledgment |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-10-community ./scripts/driver_visual_regression.sh gallery
```

---

## Deferred (Phase 12+)

- Community modals (search, notifications) — still inline in hub screen
- `ride_swap_screen.dart` polish

---

## Next

**Phase 11+** — manual ride entry, return trips, remaining ride-adjacent screens per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
