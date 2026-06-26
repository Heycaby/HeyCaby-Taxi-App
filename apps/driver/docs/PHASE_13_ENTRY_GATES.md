# Phase 13 — Entry & Gates (complete)

**Scope:** UI/design only — auth signup, WebView loading, runtime routing, and iOS gate logic unchanged.

**Frozen:** 2026-05-19 · Four entry/gate surfaces redesigned using Phase 2 kit.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `register_screen.dart` | Onboarding Gate | `DriverOnboardingGateBody` |
| `driver_help_articles_screen.dart` | Knowledge Base | `DriverKnowledgeBaseBody` |
| `driver_runtime_gate_screen.dart` | Readiness Gate | `DriverReadinessGateBody` |
| `driver_ios_update_required_app.dart` | Update Gate | `DriverUpdateGateBody` |

Shared components in `driver_entry_flow_common.dart`: scaffold, gate hero icon, gate action column, knowledge-base placeholder (goldens).

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `onboarding_gate_light.png` | Onboarding Gate |
| `knowledge_base_light.png` | Knowledge Base |
| `readiness_gate_light.png` | Readiness Gate |
| `update_gate_light.png` | Update Gate |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-13-entry-gates ./scripts/driver_visual_regression.sh gallery
```

---

## Deferred (Phase 14+)

- Community hub modals (search, notifications)
- Remaining secondary screens from blueprint

---

## Next

**Phase 14+** — splash, work hub, rider chat per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
