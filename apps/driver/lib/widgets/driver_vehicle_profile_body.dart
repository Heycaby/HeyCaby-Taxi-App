import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import '../ui/driver_text_field.dart';
import 'driver_settings_flow_common.dart';

enum DriverVehiclePlateStatus { idle, checking, taxi, notTaxi, notFound }

/// **Vehicle Profile** — kenteken + RDW verification.
class DriverVehicleProfileBody extends StatelessWidget {
  const DriverVehicleProfileBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.plateLocked,
    required this.displayPlate,
    required this.plateController,
    required this.status,
    required this.saving,
    required this.canSave,
    required this.rdwMake,
    required this.rdwModel,
    required this.rdwApk,
    required this.onBack,
    required this.onLookupPlate,
    required this.onSave,
    this.flowTitle,
    this.headerTitle,
    this.headerSubtitle,
    this.saveLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool plateLocked;
  final String displayPlate;
  final TextEditingController plateController;
  final DriverVehiclePlateStatus status;
  final bool saving;
  final bool canSave;
  final String? rdwMake;
  final String? rdwModel;
  final String? rdwApk;
  final VoidCallback onBack;
  final VoidCallback onLookupPlate;
  final VoidCallback onSave;
  final String? flowTitle;
  final String? headerTitle;
  final String? headerSubtitle;
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    return DriverSettingsFlowScaffold(
      title: flowTitle ?? DriverStrings.vehicle,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          DriverSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DriverSettingsHeader(
              title: headerTitle ?? DriverStrings.vehicleRdwTitle,
              subtitle: plateLocked
                  ? DriverStrings.vehiclePlateLockedSubtitle
                  : (headerSubtitle ?? DriverStrings.vehicleRdwSubtitle),
              colors: colors,
              typography: typography,
            ),
            if (plateLocked) ...[
              _LockedPlateRow(
                colors: colors,
                typography: typography,
                plate: displayPlate,
              ).driverFadeSlideIn(staggerIndex: 0),
              const SizedBox(height: DriverSpacing.md),
              Text(
                DriverStrings.fieldLockedContactSupport,
                style: typography.bodySmall.copyWith(
                  color: colors.textMuted,
                  height: 1.35,
                ),
              ),
              if (rdwMake != null || rdwModel != null) ...[
                const SizedBox(height: DriverSpacing.xl),
                _RdwDetailsCard(
                  colors: colors,
                  typography: typography,
                  make: rdwMake,
                  model: rdwModel,
                  apk: rdwApk,
                ).driverFadeSlideIn(staggerIndex: 1),
              ],
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DriverSpacing.md,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'NL',
                      style: typography.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DriverTextField(
                      controller: plateController,
                      colors: colors,
                      typography: typography,
                      label: DriverStrings.vehicle,
                      hint: 'XX-000-X',
                      onSubmitted: (_) => onLookupPlate(),
                    ),
                  ),
                ],
              ).driverFadeSlideIn(staggerIndex: 0),
              const SizedBox(height: DriverSpacing.sm),
              DriverButton(
                label: DriverStrings.lookupPlate,
                icon: Icons.search_rounded,
                onPressed: saving ? null : onLookupPlate,
                loading: status == DriverVehiclePlateStatus.checking,
                variant: DriverButtonVariant.outline,
                colors: colors,
                typography: typography,
              ),
              if (status == DriverVehiclePlateStatus.notFound) ...[
                const SizedBox(height: DriverSpacing.md),
                Text(
                  DriverStrings.plateNotFoundRdw,
                  style: typography.bodySmall.copyWith(color: colors.error),
                ),
              ],
              if (status == DriverVehiclePlateStatus.notTaxi) ...[
                const SizedBox(height: DriverSpacing.lg),
                DriverCard(
                  colors: colors,
                  child: Text(
                    DriverStrings.vehicleNotTaxiRdw,
                    style: typography.bodySmall.copyWith(
                      color: colors.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (status == DriverVehiclePlateStatus.taxi) ...[
                const SizedBox(height: DriverSpacing.lg),
                _RdwDetailsCard(
                  colors: colors,
                  typography: typography,
                  make: rdwMake,
                  model: rdwModel,
                  apk: rdwApk,
                  verified: true,
                ),
                const SizedBox(height: DriverSpacing.xl),
                DriverButton(
                  label: saveLabel ?? DriverStrings.saveAction,
                  onPressed: canSave && !saving ? onSave : null,
                  loading: saving,
                  colors: colors,
                  typography: typography,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LockedPlateRow extends StatelessWidget {
  const _LockedPlateRow({
    required this.colors,
    required this.typography,
    required this.plate,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String plate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            'NL',
            style: typography.labelLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.lg,
              vertical: DriverSpacing.lg,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
            child: Text(
              plate,
              style: typography.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RdwDetailsCard extends StatelessWidget {
  const _RdwDetailsCard({
    required this.colors,
    required this.typography,
    this.make,
    this.model,
    this.apk,
    this.verified = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String? make;
  final String? model;
  final String? apk;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  verified
                      ? DriverStrings.vehicleVerifiedTaxi
                      : DriverStrings.vehicleRdwTitle,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (verified)
                DriverStatusBadge(
                  label: DriverStrings.statusVerified,
                  colors: colors,
                  typography: typography,
                  tone: DriverStatusTone.success,
                ),
            ],
          ),
          if (make != null) ...[
            const SizedBox(height: DriverSpacing.md),
            _kv('Merk', make!, typography, colors),
          ],
          if (model != null) _kv('Model', model!, typography, colors),
          if (apk != null) _kv('APK', apk!, typography, colors),
        ],
      ),
    );
  }

  Widget _kv(
    String k,
    String v,
    DriverTypography typography,
    DriverColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: typography.bodySmall.copyWith(color: colors.textMuted)),
          Text(
            v,
            style: typography.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
