import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_flow_common.dart';

/// **Active Trip** — navigate to pickup; rider + ETA obvious.
class DriverActiveTripBody extends StatelessWidget {
  const DriverActiveTripBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.riderName,
    required this.requestsPaused,
    required this.statusBusy,
    required this.arriving,
    required this.onBack,
    required this.onArrived,
    required this.onNavigate,
    required this.onOpenCommunication,
    required this.onCancelOrder,
    required this.onToggleRequests,
    this.showNearPickupAssist = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final bool requestsPaused;
  final bool statusBusy;
  final bool arriving;
  final VoidCallback onBack;
  final VoidCallback onArrived;
  final VoidCallback onNavigate;
  final VoidCallback onOpenCommunication;
  final VoidCallback onCancelOrder;
  final VoidCallback onToggleRequests;
  final bool showNearPickupAssist;

  @override
  Widget build(BuildContext context) {
    return DriverRideFlowScaffold(
      title: DriverStrings.navigateToPickup,
      colors: colors,
      typography: typography,
      onBack: onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriverStatusBadge(
            label: DriverStrings.navigateToPickup,
            colors: colors,
            typography: typography,
            tone: DriverStatusTone.online,
            icon: Icons.navigation_rounded,
          ).driverFadeSlideIn(staggerIndex: 0),
          if (showNearPickupAssist) ...[
            const SizedBox(height: DriverSpacing.sm),
            DriverStatusBadge(
              label: DriverStrings.nearPickupAssistBanner,
              colors: colors,
              typography: typography,
              tone: DriverStatusTone.success,
              icon: Icons.near_me_rounded,
            ).driverFadeSlideIn(staggerIndex: 0),
          ],
          const SizedBox(height: DriverSpacing.lg),
          DriverRideTripSummary(
            colors: colors,
            typography: typography,
            pickupLabel: pickupAddress,
            dropoffLabel: destinationAddress,
            riderName: riderName,
            statusLabel: DriverStrings.pickup,
            statusTone: DriverStatusTone.success,
          ),
          const SizedBox(height: DriverSpacing.xl),
          DriverRideActionGrid(
            colors: colors,
            typography: typography,
            actions: [
              DriverRideFlowAction(
                label: DriverStrings.navigate,
                icon: Icons.navigation_outlined,
                onTap: onNavigate,
              ),
              DriverRideFlowAction(
                label: DriverStrings.communicationOpen,
                icon: Icons.forum_outlined,
                onTap: onOpenCommunication,
              ),
              DriverRideFlowAction(
                label: requestsPaused
                    ? DriverStrings.resumeRequests
                    : DriverStrings.stopNewRequests,
                icon: Icons.pause_circle_outline,
                onTap: onToggleRequests,
                enabled: !statusBusy,
              ),
              DriverRideFlowAction(
                label: DriverStrings.cancelOrder,
                icon: Icons.cancel_outlined,
                onTap: onCancelOrder,
                enabled: !statusBusy,
              ),
            ],
          ),
        ],
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.iHaveArrived,
        primaryIcon: Icons.place_rounded,
        onPrimary: arriving ? null : onArrived,
        primaryLoading: arriving,
      ),
    );
  }
}
