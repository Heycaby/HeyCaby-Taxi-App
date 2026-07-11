import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_compliance_vault_body.dart';
import 'package:heycaby_driver/widgets/driver_identity_body.dart';
import 'package:heycaby_driver/widgets/driver_preferences_body.dart';
import 'package:heycaby_driver/widgets/driver_vehicle_profile_body.dart';
import 'package:heycaby_driver/widgets/driver_veriff_trust_body.dart';

/// Golden preview — Driver Identity (Account Hub).
class DriverIdentityPreview extends StatelessWidget {
  const DriverIdentityPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: DriverIdentityBody(
        colors: colors,
        typography: typography,
        model: DriverIdentityViewModel(
          headline: 'Jan de Vries',
          initials: 'JV',
          email: 'jan@example.nl',
          rating: 4.92,
          vehiclePlate: 'TX-123-B',
          vehicleDisplay: 'Mercedes E-Klasse · Zwart',
          foundingNumber: 42,
          showFoundingShield: true,
          isVerifiedBadge: true,
          showVehicleVerified: true,
          apkExpiryLabel: '12/8/2026',
          completionItems: [
            DriverIdentityRequirement(
              key: 'driver_photo',
              label: DriverStrings.profileRequirementDriverPhoto,
              complete: true,
            ),
            DriverIdentityRequirement(
              key: 'vehicle_photo',
              label: DriverStrings.profileRequirementVehiclePhoto,
              complete: false,
            ),
          ],
        ),
        onEditProfile: () {},
        onOpenVehicle: () {},
        onAddVehiclePhoto: () {},
        onOpenRatings: () {},
        onOpenSettings: () {},
        onOpenRequirement: (_) {},
      ),
    );
  }
}

/// Golden preview — Preferences.
class DriverPreferencesPreview extends StatelessWidget {
  const DriverPreferencesPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverPreferencesBody(
      colors: colors,
      typography: typography,
      vehicleSubtitle: 'Mercedes E-Klasse · Zwart',
      languageSubtitle: 'Nederlands',
      acceptsCash: true,
      acceptsCard: true,
      acceptsTikkie: false,
      acceptsInvoice: true,
      petFriendly: true,
      wheelchairAccessible: false,
      onBack: () {},
      onVehicle: () {},
      onLanguage: () {},
      onCashChanged: (_) {},
      onCardChanged: (_) {},
      onTikkieChanged: (_) {},
      onInvoiceChanged: (_) {},
      onPetFriendlyChanged: (_) {},
      onWheelchairChanged: (_) {},
    );
  }
}

/// Golden preview — Vehicle Profile (editable plate).
class DriverVehicleProfilePreview extends StatefulWidget {
  const DriverVehicleProfilePreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverVehicleProfilePreview> createState() =>
      _DriverVehicleProfilePreviewState();
}

class _DriverVehicleProfilePreviewState
    extends State<DriverVehicleProfilePreview> {
  late final TextEditingController _plateCtrl;

  @override
  void initState() {
    super.initState();
    _plateCtrl = TextEditingController(text: 'TX123B');
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DriverVehicleProfileBody(
      colors: widget.colors,
      typography: widget.typography,
      plateLocked: false,
      displayPlate: 'TX-123-B',
      plateController: _plateCtrl,
      status: DriverVehiclePlateStatus.taxi,
      saving: false,
      canSave: true,
      rdwMake: 'MERCEDES-BENZ',
      rdwModel: 'E 220 D',
      rdwApk: '2026-08-12',
      onBack: () {},
      onLookupPlate: () {},
      onSave: () {},
    );
  }
}

/// Golden preview — Veriff trust entry.
class DriverVeriffTrustPreview extends StatelessWidget {
  const DriverVeriffTrustPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverVeriffTrustBody(
      colors: colors,
      typography: typography,
      loading: false,
      message: null,
      messageOk: null,
      onBack: () {},
      onContinue: () {},
    );
  }
}

/// Golden preview — Compliance Vault shell + sample checklist.
class DriverComplianceVaultPreview extends StatelessWidget {
  const DriverComplianceVaultPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _checklist = [
    DriverComplianceChecklistItem(
      title: 'Chauffeurspas',
      complete: true,
    ),
    DriverComplianceChecklistItem(
      title: 'Identiteitsverificatie',
      complete: false,
    ),
    DriverComplianceChecklistItem(
      title: 'Voertuig (RDW)',
      complete: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverComplianceVaultBody(
      colors: colors,
      typography: typography,
      checklistTitle: DriverStrings.goOnlineChecklistTitle,
      checklistHint: DriverStrings.goOnlineChecklistHint,
      items: _checklist,
      onBack: () {},
      onRefreshChecklist: () {},
      content: Text(
        DriverStrings.legalChecklistTitle,
        style: typography.labelMedium.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
