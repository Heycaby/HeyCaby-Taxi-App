import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_flow_common.dart';

/// **Pickup Arrival** — confirm arrival; start trip friction-free.
class DriverPickupArrivalBody extends StatelessWidget {
  const DriverPickupArrivalBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.riderName,
    required this.waitSeconds,
    required this.waitingGraceSeconds,
    required this.waitingRatePerMinute,
    required this.waitingFeeWaived,
    required this.canReportNoShow,
    required this.loading,
    required this.onBack,
    required this.onStartRide,
    required this.onOpenCommunication,
    required this.onWaiveWaitingFee,
    required this.onReportNoShow,
    required this.onCancelRide,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final int waitSeconds;
  final int waitingGraceSeconds;
  final double waitingRatePerMinute;
  final bool waitingFeeWaived;
  final bool canReportNoShow;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onStartRide;
  final VoidCallback onOpenCommunication;
  final VoidCallback onWaiveWaitingFee;
  final VoidCallback onReportNoShow;
  final VoidCallback onCancelRide;

  @override
  Widget build(BuildContext context) {
    return DriverRideFlowScaffold(
      title: DriverStrings.atPickup,
      colors: colors,
      typography: typography,
      onBack: onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriverStatusBadge(
            label: DriverStrings.prerideAwaitingRider,
            colors: colors,
            typography: typography,
            tone: DriverStatusTone.warning,
            icon: Icons.schedule_rounded,
          ).driverFadeSlideIn(staggerIndex: 0),
          const SizedBox(height: DriverSpacing.sm),
          _WaitingFeeCard(
            colors: colors,
            typography: typography,
            waitSeconds: waitSeconds,
            graceSeconds: waitingGraceSeconds,
            ratePerMinute: waitingRatePerMinute,
            waived: waitingFeeWaived,
            loading: loading,
            onWaive: onWaiveWaitingFee,
          ).driverFadeSlideIn(staggerIndex: 1),
          const SizedBox(height: DriverSpacing.lg),
          DriverRideTripSummary(
            colors: colors,
            typography: typography,
            pickupLabel: pickupAddress,
            dropoffLabel: destinationAddress,
            riderName: riderName,
            statusLabel: DriverStrings.atPickup,
            statusTone: DriverStatusTone.warning,
            staggerIndex: 1,
          ),
          const SizedBox(height: DriverSpacing.xl),
          DriverRideActionGrid(
            colors: colors,
            typography: typography,
            actions: [
              DriverRideFlowAction(
                label: DriverStrings.communicationOpen,
                icon: Icons.forum_outlined,
                onTap: onOpenCommunication,
                enabled: !loading,
              ),
              DriverRideFlowAction(
                label: DriverStrings.cancelOrder,
                icon: Icons.cancel_outlined,
                onTap: onCancelRide,
                enabled: !loading,
              ),
            ],
          ),
        ],
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.startRide,
        primaryIcon: Icons.play_arrow_rounded,
        onPrimary: loading ? null : onStartRide,
        primaryLoading: loading,
        tertiaryLabel: canReportNoShow ? DriverStrings.riderDidNotShow : null,
        onTertiary: canReportNoShow && !loading ? onReportNoShow : null,
        tertiaryDestructive: true,
      ),
    );
  }
}

class _WaitingFeeCard extends StatelessWidget {
  const _WaitingFeeCard({
    required this.colors,
    required this.typography,
    required this.waitSeconds,
    required this.graceSeconds,
    required this.ratePerMinute,
    required this.waived,
    required this.loading,
    required this.onWaive,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int waitSeconds;
  final int graceSeconds;
  final double ratePerMinute;
  final bool waived;
  final bool loading;
  final VoidCallback onWaive;

  int get _chargeableSeconds {
    final seconds = waitSeconds - graceSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  int get _remainingGraceSeconds {
    final seconds = graceSeconds - waitSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  int get _feeCents {
    if (waived || ratePerMinute <= 0) return 0;
    return ((_chargeableSeconds / 60) * ratePerMinute * 100).round();
  }

  String _duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }

  String _money(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final inGrace = _chargeableSeconds == 0 && !waived;
    final title = waived
        ? 'Waiting fee waived'
        : inGrace
            ? 'Free pickup time'
            : 'Waiting time';
    final mainValue = waived
        ? _money(0)
        : inGrace
            ? _duration(_remainingGraceSeconds)
            : _duration(_chargeableSeconds);
    final subtitle = waived
        ? 'The rider has been notified.'
        : inGrace
            ? 'Fee starts after grace time.'
            : '${_money(_feeCents)} added so far';
    final rateLabel = ratePerMinute > 0
        ? 'Rate: €${ratePerMinute.toStringAsFixed(2)}/min'
        : 'Waiting rate not set';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: waived
            ? colors.success.withValues(alpha: 0.08)
            : colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: waived
              ? colors.success.withValues(alpha: 0.22)
              : colors.warning.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.card,
              border: Border.all(
                color: waived ? colors.success : colors.warning,
                width: 4,
              ),
            ),
            child: Center(
              child: Text(
                mainValue,
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rateLabel,
                  style: typography.labelMedium.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!waived && _feeCents > 0) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: loading ? null : onWaive,
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Waive waiting fee'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
