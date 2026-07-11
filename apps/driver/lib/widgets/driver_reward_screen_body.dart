import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_ride_bolt_layout.dart';
import 'driver_ride_flow_common.dart';

/// **Reward Screen** — trip complete summary; rate rider (payment via collect sheet).
class DriverRewardScreenBody extends StatelessWidget {
  const DriverRewardScreenBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.destinationAddress,
    required this.expectedLabel,
    required this.onRateRider,
    required this.onSkip,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.baseFareLabel,
    this.waitingFeeLabel,
    this.waitingFeeWaived = false,
    this.paymentConfirmed = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String destinationAddress;
  final String? expectedLabel;
  final String? baseFareLabel;
  final String? waitingFeeLabel;
  final bool waitingFeeWaived;
  final bool paymentConfirmed;
  final VoidCallback onRateRider;
  final VoidCallback onSkip;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  String _formatEuro(String? label) {
    if (label == null || label.trim().isEmpty) return '—';
    return label.replaceFirst('EUR ', '€');
  }

  @override
  Widget build(BuildContext context) {
    final colors = this.colors;
    final typography = this.typography;
    final waitingLabel = waitingFeeWaived
        ? DriverStrings.waitingFeeWaived
        : _formatEuro(waitingFeeLabel);

    return DriverRideBoltScaffold(
      colors: colors,
      typography: typography,
      phase: DriverRideBoltPhase.completed,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      driverLat: destLat,
      driverLng: destLng,
      onClose: onSkip,
      scrollableInfoCard: true,
      infoCard: DriverRideBoltInfoCard(
        colors: colors,
        typography: typography,
        heroPrimary: driverRideBoltFareHero(expectedLabel),
        heroSecondary: DriverStrings.rideCompleted,
        focusAddress: destinationAddress,
        successTone: true,
        extra: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: DriverSpacing.xs),
            _MinimalFareLine(
              colors: colors,
              typography: typography,
              label: DriverStrings.rideFareLabel,
              value: _formatEuro(baseFareLabel),
            ),
            const SizedBox(height: DriverSpacing.sm),
            _MinimalFareLine(
              colors: colors,
              typography: typography,
              label: DriverStrings.waitingFeeLabel,
              value: waitingLabel,
              muted: waitingFeeWaived,
            ),
            if (paymentConfirmed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DriverSpacing.lg),
                child: Divider(
                  color: colors.border.withValues(alpha: 0.45),
                  height: 1,
                ),
              ),
              Text(
                DriverStrings.paymentCashCollected,
                textAlign: TextAlign.center,
                style: typography.titleSmall.copyWith(
                  color: colors.success,
                  fontWeight: FontWeight.w800,
                ),
              ).driverFadeSlideIn(staggerIndex: 0),
            ],
          ],
        ),
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.rateRider,
        primaryIcon: Icons.star_rounded,
        onPrimary: onRateRider,
        tertiaryLabel: DriverStrings.skip,
        onTertiary: onSkip,
      ),
    );
  }
}

class _MinimalFareLine extends StatelessWidget {
  const _MinimalFareLine({
    required this.colors,
    required this.typography,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final labelStyle = typography.bodySmall.copyWith(
      color: colors.textSecondary,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = typography.bodyMedium.copyWith(
      color: muted ? colors.primary : colors.text,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
