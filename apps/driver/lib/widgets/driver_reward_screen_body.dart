import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_chip.dart';
import '../ui/driver_text_field.dart';
import 'driver_ride_bolt_layout.dart';
import 'driver_ride_flow_common.dart';

/// **Reward Screen** — minimalist trip complete; record payment; rate rider.
class DriverRewardScreenBody extends StatefulWidget {
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
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
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
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  @override
  State<DriverRewardScreenBody> createState() => _DriverRewardScreenBodyState();
}

class _DriverRewardScreenBodyState extends State<DriverRewardScreenBody> {
  bool _noteExpanded = false;

  List<(String, String)> _paymentMethods() => [
        ('cash', DriverStrings.cash),
        ('card', DriverStrings.card),
        ('tikkie', 'Tikkie'),
        ('other', DriverStrings.other),
      ];

  String _formatEuro(String? label) {
    if (label == null || label.trim().isEmpty) return '—';
    return label.replaceFirst('EUR ', '€');
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;
    final waitingLabel = widget.waitingFeeWaived
        ? DriverStrings.waitingFeeWaived
        : _formatEuro(widget.waitingFeeLabel);

    return DriverRideBoltScaffold(
      colors: colors,
      typography: typography,
      phase: DriverRideBoltPhase.completed,
      pickupLat: widget.pickupLat,
      pickupLng: widget.pickupLng,
      destLat: widget.destLat,
      destLng: widget.destLng,
      driverLat: widget.destLat,
      driverLng: widget.destLng,
      onClose: widget.onSkip,
      scrollableInfoCard: true,
      infoCard: DriverRideBoltInfoCard(
        colors: colors,
        typography: typography,
        heroPrimary: driverRideBoltFareHero(widget.expectedLabel),
        heroSecondary: DriverStrings.rideCompleted,
        focusAddress: widget.destinationAddress,
        successTone: true,
        extra: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: DriverSpacing.xs),
            _MinimalFareLine(
              colors: colors,
              typography: typography,
              label: DriverStrings.rideFareLabel,
              value: _formatEuro(widget.baseFareLabel),
            ),
            const SizedBox(height: DriverSpacing.sm),
            _MinimalFareLine(
              colors: colors,
              typography: typography,
              label: DriverStrings.waitingFeeLabel,
              value: waitingLabel,
              muted: widget.waitingFeeWaived,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DriverSpacing.lg),
              child: Divider(
                color: colors.border.withValues(alpha: 0.45),
                height: 1,
              ),
            ),
            Text(
              DriverStrings.recordPaymentReceived,
              style: typography.labelMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ).driverFadeSlideIn(staggerIndex: 0),
            const SizedBox(height: DriverSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DriverTextField(
                    controller: widget.paidController,
                    colors: colors,
                    typography: typography,
                    label: DriverStrings.paidAmountLabel,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DriverSpacing.md),
            Wrap(
              spacing: DriverSpacing.sm,
              runSpacing: DriverSpacing.sm,
              children: [
                for (final (value, label) in _paymentMethods())
                  DriverChip(
                    label: label,
                    colors: colors,
                    typography: typography,
                    selected: widget.paymentMethod == value,
                    onTap: () => widget.onPaymentMethodChanged(value),
                  ),
              ],
            ),
            const SizedBox(height: DriverSpacing.sm),
            if (!_noteExpanded)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() => _noteExpanded = true),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    DriverStrings.accountingNoteLabel,
                    style: typography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: DriverSpacing.sm),
              DriverTextField(
                controller: widget.noteController,
                colors: colors,
                typography: typography,
                label: DriverStrings.accountingNoteLabel,
                hint: DriverStrings.accountingNoteLabel,
              ),
            ],
            const SizedBox(height: DriverSpacing.md),
            Align(
              alignment: AlignmentDirectional.center,
              child: TextButton.icon(
                onPressed: widget.sendingReceipt ? null : widget.onSendReceipt,
                icon: widget.sendingReceipt
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                label: Text(
                  widget.sendingReceipt
                      ? DriverStrings.sendingReceipt
                      : DriverStrings.sendReceipt,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.rateRider,
        primaryIcon: Icons.star_rounded,
        onPrimary: widget.onRateRider,
        tertiaryLabel: DriverStrings.skip,
        onTertiary: widget.onSkip,
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
