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
    this.baseFareLabel,
    this.waitingFeeLabel,
    this.waitingFeeWaived = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String destinationAddress;
  final String? expectedLabel;
  final String? baseFareLabel;
  final String? waitingFeeLabel;
  final bool waitingFeeWaived;
  final TextEditingController paidController;
  final TextEditingController noteController;
  final String paymentMethod;
  final bool sendingReceipt;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onSendReceipt;
  final VoidCallback onRateRider;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  List<(String, String)> _paymentMethods() => [
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
                _FareBreakdownCard(
                  colors: colors,
                  typography: typography,
                  baseFareLabel: baseFareLabel ?? expectedLabel,
                  waitingFeeLabel: waitingFeeLabel,
                  waitingFeeWaived: waitingFeeWaived,
                  totalLabel: expectedLabel,
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
                    for (final (value, label) in _paymentMethods())
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

class _FareBreakdownCard extends StatelessWidget {
  const _FareBreakdownCard({
    required this.colors,
    required this.typography,
    required this.baseFareLabel,
    required this.waitingFeeLabel,
    required this.waitingFeeWaived,
    required this.totalLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String? baseFareLabel;
  final String? waitingFeeLabel;
  final bool waitingFeeWaived;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    final waitingLabel = waitingFeeWaived
        ? DriverStrings.waitingFeeWaived
        : waitingFeeLabel ?? '-';

    return Container(
      padding: const EdgeInsets.all(DriverSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Text(
                  DriverStrings.fareBreakdownTitle,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          _FareRow(
            colors: colors,
            typography: typography,
            label: DriverStrings.rideFareLabel,
            value: baseFareLabel ?? '-',
          ),
          const SizedBox(height: DriverSpacing.sm),
          _FareRow(
            colors: colors,
            typography: typography,
            label: DriverStrings.waitingFeeLabel,
            value: waitingLabel,
            highlight: waitingFeeWaived,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DriverSpacing.md),
            child: Divider(color: colors.border, height: 1),
          ),
          _FareRow(
            colors: colors,
            typography: typography,
            label: DriverStrings.totalToRecordLabel,
            value: totalLabel ?? '-',
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.colors,
    required this.typography,
    required this.label,
    required this.value,
    this.strong = false,
    this.highlight = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final String value;
  final bool strong;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (strong ? typography.labelLarge : typography.bodySmall)
                .copyWith(
              color: strong ? colors.text : colors.textSecondary,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: DriverSpacing.md),
        Text(
          value,
          style: (strong ? typography.titleMedium : typography.bodyMedium)
              .copyWith(
            color: highlight ? colors.primary : colors.text,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
