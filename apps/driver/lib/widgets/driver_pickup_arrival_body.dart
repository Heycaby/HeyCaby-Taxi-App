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
    required this.canReportNoShow,
    required this.loading,
    required this.onBack,
    required this.onStartRide,
    required this.onOpenCommunication,
    required this.onReportNoShow,
    required this.onCancelRide,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final int waitSeconds;
  final bool canReportNoShow;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onStartRide;
  final VoidCallback onOpenCommunication;
  final VoidCallback onReportNoShow;
  final VoidCallback onCancelRide;

  String get _waitLabel {
    final m = waitSeconds ~/ 60;
    final s = (waitSeconds % 60).toString().padLeft(2, '0');
    return '${DriverStrings.waiting}: $m:$s';
  }

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
          Text(
            _waitLabel,
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
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
        tertiaryLabel:
            canReportNoShow ? DriverStrings.riderDidNotShow : null,
        onTertiary: canReportNoShow && !loading ? onReportNoShow : null,
        tertiaryDestructive: true,
      ),
    );
  }
}
