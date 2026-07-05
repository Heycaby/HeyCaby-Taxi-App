import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_flow_common.dart';

/// **Navigation Focus** — driving-first; minimal distraction.
class DriverNavigationFocusBody extends StatelessWidget {
  const DriverNavigationFocusBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.riderName,
    required this.expectedAmountLabel,
    required this.completing,
    required this.onBack,
    required this.onNavigate,
    required this.onCompleteRide,
    required this.onOpenCommunication,
    required this.onCancelRide,
    this.showNearDestinationAssist = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final String? expectedAmountLabel;
  final bool completing;
  final VoidCallback onBack;
  final VoidCallback onNavigate;
  final VoidCallback onCompleteRide;
  final VoidCallback onOpenCommunication;
  final VoidCallback onCancelRide;
  final bool showNearDestinationAssist;

  @override
  Widget build(BuildContext context) {
    return DriverRideFlowScaffold(
      title: DriverStrings.rideInProgress,
      colors: colors,
      typography: typography,
      onBack: onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriverRidePhaseHero(
            colors: colors,
            typography: typography,
            eyebrow: DriverStrings.rideInProgress,
            title: DriverStrings.inProgressHeroTitle,
            body: DriverStrings.inProgressHeroBody,
            icon: Icons.directions_car_rounded,
            tone: DriverStatusTone.online,
            metric: expectedAmountLabel,
          ),
          if (showNearDestinationAssist) ...[
            const SizedBox(height: DriverSpacing.sm),
            DriverStatusBadge(
              label: DriverStrings.nearDestinationAssistBanner,
              colors: colors,
              typography: typography,
              tone: DriverStatusTone.success,
              icon: Icons.flag_circle_outlined,
            ).driverFadeSlideIn(staggerIndex: 0),
          ],
          const SizedBox(height: DriverSpacing.lg),
          DriverRideTripSummary(
            colors: colors,
            typography: typography,
            pickupLabel: pickupAddress,
            dropoffLabel: destinationAddress,
            riderName: riderName,
            statusLabel: DriverStrings.destination,
            statusTone: DriverStatusTone.success,
            staggerIndex: 1,
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
                label: DriverStrings.pingRiderAction,
                icon: Icons.forum_outlined,
                onTap: onOpenCommunication,
                enabled: !completing,
              ),
              DriverRideFlowAction(
                label: DriverStrings.cancelOrder,
                icon: Icons.cancel_outlined,
                onTap: onCancelRide,
                enabled: !completing,
              ),
            ],
          ),
        ],
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.completeRide,
        primaryIcon: Icons.flag_rounded,
        onPrimary: completing ? null : onCompleteRide,
        primaryLoading: completing,
      ),
    );
  }
}
