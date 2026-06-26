# Phase 6 — Support & Help (complete)

**Scope:** UI/design only — logic, navigation, API contracts, and support flows unchanged.

**Frozen:** 2026-05-19 · Four support screens redesigned using Phase 2 kit + support shell.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `driver_support_screen.dart` | Help Hub | `DriverHelpHubBody` |
| `driver_faq_screen.dart` | Quick Answers | `DriverQuickAnswersBody` |
| `support_threads_screen.dart` | Support Inbox | `DriverSupportInboxBody` |
| `support_new_ticket_screen.dart` | Raise Issue | `DriverRaiseIssueBody` |

Shared components: `DriverSupportFlowScaffold` (alias of settings shell), `DriverSupportFeaturedRow`, `DriverSupportNavRow`, `DriverSupportTicketRow`, `DriverSupportSectionCard` in `driver_support_flow_common.dart`.

Chat surfaces (`support_chat_screen.dart`, `support_lee_screen.dart`) remain on legacy layout — Phase 8+.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `help_hub_light.png` | Help Hub |
| `quick_answers_light.png` | Quick Answers (FAQ) |
| `support_inbox_light.png` | Support Inbox |
| `raise_issue_light.png` | Raise Issue |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-6-support ./scripts/driver_visual_regression.sh gallery
```

---

## Next

**Phase 8+** — demand/performance (hotspots, score, tariff), community, chat polish, or manual ride entry per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
