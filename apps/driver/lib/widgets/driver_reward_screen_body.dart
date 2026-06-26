import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_chip.dart';
import '../ui/driver_text_field.dart';
import 'driver_ride_flow_common.dart';

/// **Reward Screen** — celebrate completion; record payment; rate rider.
class DriverRewardScreenBody extends StatelessWidget {
  const DriverRewardScreenBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.destinationAddress,
    required this.expectedLabel,
    required this.paidController,
    required this.noteController,
    required this.paymentMethod,
    required this.sendingReceipt,
    required this.onPaymentMethodChanged,
    required this.onSendReceipt,
    required this.onRateRider,
    required this.onSkip,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String destinationAddress;
  final String? expectedLabel;
  final TextEditingController paidController;
  final TextEditingController noteController;
  final String paymentMethod;
  final bool sendingReceipt;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onSendReceipt;
  final VoidCallback onRateRider;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  static const _methods = [
    ('cash', DriverStrings.cash),
    ('card', DriverStrings.card),
    ('tikkie', 'Tikkie'),
    ('other', DriverStrings.other),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverRideFlowScaffold(
      title: DriverStrings.rideCompleteTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 72,
            color: colors.primary,
          ).driverSuccessPop(),
          const SizedBox(height: DriverSpacing.md),
          Text(
            DriverStrings.rideCompleted,
            style: typography.headlineMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ).driverFadeSlideIn(staggerIndex: 0),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            destinationAddress,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ).driverFadeSlideIn(staggerIndex: 1),
          const SizedBox(height: DriverSpacing.xl),
          DriverCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverStrings.recordPaymentReceived,
                  style: typography.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  '${DriverStrings.expectedFareLabel}: ${expectedLabel ?? '—'}',
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: DriverSpacing.lg),
                DriverTextField(
                  controller: paidController,
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.paidAmountLabel,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: DriverSpacing.md),
                Text(
                  DriverStrings.paymentMethodLabel,
                  style: typography.labelMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                Wrap(
                  spacing: DriverSpacing.sm,
                  runSpacing: DriverSpacing.sm,
                  children: [
                    for (final (value, label) in _methods)
                      DriverChip(
                        label: label,
                        colors: colors,
                        typography: typography,
                        selected: paymentMethod == value,
                        onTap: () => onPaymentMethodChanged(value),
                      ),
                  ],
                ),
                const SizedBox(height: DriverSpacing.md),
                DriverTextField(
                  controller: noteController,
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.accountingNoteLabel,
                  hint: DriverStrings.accountingNoteLabel,
                ),
                const SizedBox(height: DriverSpacing.lg),
                DriverButton(
                  label: sendingReceipt
                      ? DriverStrings.sendingReceipt
                      : DriverStrings.sendReceipt,
                  icon: Icons.receipt_long_rounded,
                  onPressed: sendingReceipt ? null : onSendReceipt,
                  loading: sendingReceipt,
                  colors: colors,
                  typography: typography,
                  variant: DriverButtonVariant.secondary,
                ),
              ],
            ),
          ).driverFadeSlideIn(staggerIndex: 2),
        ],
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
