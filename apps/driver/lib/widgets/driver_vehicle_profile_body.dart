import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
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
              _DutchPlateField(
                controller: plateController,
                colors: colors,
                typography: typography,
                enabled: !saving,
                onSubmitted: onLookupPlate,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DriverStrings.vehiclePlate,
          style: typography.labelMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DriverSpacing.sm),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DriverRadius.smAll,
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 56,
                alignment: Alignment.center,
                color: colors.surface,
                child: Text(
                  'NL',
                  style: typography.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(width: 1, color: colors.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      plate,
                      style: typography.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DutchPlateField extends StatelessWidget {
  const _DutchPlateField({
    required this.controller,
    required this.colors,
    required this.typography,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final DriverColors colors;
  final DriverTypography typography;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DriverStrings.vehiclePlate,
          style: typography.labelMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DriverSpacing.sm),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DriverRadius.smAll,
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 56,
                alignment: Alignment.center,
                color: colors.surface,
                child: Text(
                  'NL',
                  style: typography.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(width: 1, color: colors.border),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmitted(),
                  style: typography.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XX-000-X',
                    hintStyle: typography.bodyMedium.copyWith(
                      color: colors.textMuted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DriverSpacing.lg,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
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
            _kv(DriverStrings.vehicleMake, make!, typography, colors),
          ],
          if (model != null)
            _kv(DriverStrings.vehicleModel, model!, typography, colors),
          if (apk != null)
            _kv(DriverStrings.vehicleApk, apk!, typography, colors),
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
          Text(k,
              style: typography.bodySmall.copyWith(color: colors.textMuted)),
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
