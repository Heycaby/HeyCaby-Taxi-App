# Phase 14 — Active Hub (complete)

**Scope:** UI/design only — splash animation timing, work tab providers, chat realtime, and community posts unchanged.

**Frozen:** 2026-05-19 · Four active-hub surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `splash_screen.dart` | Brand Moment | `DriverBrandMomentBody` |
| `work_screen.dart` | Shift Command | `DriverShiftCommandBody` |
| `driver_chat_screen.dart` | Rider Conversation | `DriverRiderConversationBody` |
| `me_screen.dart` | Community Feed (legacy hub) | `DriverMeCommunityBody` |

Shared components:

- `driver_brand_moment_body.dart` — splash layout + loading row
- `driver_shift_command_body.dart` — earnings / available-rides tabs (providers internal)
- `driver_shift_command_flow_common.dart` — earnings snapshot preview for goldens
- `driver_rider_conversation_body.dart` — reuses `DriverSupportTicketBubble`
- `driver_me_community_body.dart` — channel pills + post cards

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `brand_moment_light.png` | Brand Moment |
| `shift_command_light.png` | Shift Command (earnings tab) |
| `rider_conversation_light.png` | Rider Conversation |
| `me_community_light.png` | Community Feed |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-14-active-hub ./scripts/driver_visual_regression.sh gallery
```

---

## Deferred (Phase 15+)

- *(none — overlay extraction complete)*

---

## Next

**Blueprint complete** — all registered screens on Phase 2 kit. See [`PHASE_15_COMMUNITY_OVERLAYS.md`](./PHASE_15_COMMUNITY_OVERLAYS.md).
