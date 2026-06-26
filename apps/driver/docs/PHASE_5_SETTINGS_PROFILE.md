# Phase 5 — Settings & Profile (complete)

**Scope:** UI/design only — logic, navigation, API contracts, and compliance flows unchanged.

**Frozen:** 2026-05-19 · Five profile/settings screens redesigned using Phase 2 kit + settings shell.

---

## Screens

| File | Purpose name | Body widget |
|------|--------------|-------------|
| `driver_profile_screen.dart` | Driver Identity (Account Hub `/driver/me`) | `DriverIdentityBody` |
| `driver_preferences_screen.dart` | Preferences | `DriverPreferencesBody` |
| `driver_documents_screen.dart` | Compliance Vault | `DriverComplianceVaultBody` |
| `driver_veriff_screen.dart` | Identity Verification | `DriverVeriffTrustBody` |
| `vehicle_edit_screen.dart` | Vehicle Profile | `DriverVehicleProfileBody` |

Shared shell: `DriverSettingsFlowScaffold`, `DriverSettingsHeader` in `driver_settings_flow_common.dart`.  
Settings rows: `DriverSettingsSectionLabel`, `DriverSettingsGroupCard`, `DriverSettingsNavRow`, `DriverSettingsToggleRow` in `lib/ui/driver_settings_row.dart`.

Document forms inside Compliance Vault still use existing `PremiumSettingsCard` rows — shell and checklist summary use the new kit.

---

## Visual regression

| Golden | Screen |
|--------|--------|
| `driver_identity_light.png` | Driver Identity |
| `preferences_light.png` | Preferences |
| `vehicle_profile_light.png` | Vehicle Profile |
| `veriff_trust_light.png` | Identity Verification |
| `compliance_vault_light.png` | Compliance Vault |

```bash
./scripts/driver_visual_regression.sh compare
PHASE=phase-5-profile ./scripts/driver_visual_regression.sh gallery
```

---

## Next

**Phase 7+** — trip ledger, demand/performance, community, chat polish per [`DRIVER_EXPERIENCE_BLUEPRINT.md`](./DRIVER_EXPERIENCE_BLUEPRINT.md).
