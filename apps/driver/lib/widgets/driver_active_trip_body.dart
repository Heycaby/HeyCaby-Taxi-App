import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../utils/driver_address_clipboard.dart';
import '../l10n/driver_strings.dart';
import '../utils/driver_nav_app_helpers.dart';
import '../providers/driver_ride_unread_messages_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_bolt_layout.dart';
import 'driver_ride_flow_common.dart';
import 'driver_taxi_terug_queued_banner_slot.dart';

/// **Active Trip** — Bolt-style en route to pickup.
class DriverActiveTripBody extends ConsumerWidget {
  const DriverActiveTripBody({
    super.key,
    required this.rideId,
    required this.colors,
    required this.typography,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.riderName,
    required this.requestsPaused,
    required this.statusBusy,
    required this.arriving,
    required this.onArrived,
    required this.onNavigate,
    required this.onOpenCommunication,
    required this.onCancelOrder,
    required this.onToggleRequests,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
    this.farePill,
    this.onSafety,
    this.showNearPickupAssist = false,
  });

  final String rideId;
  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final bool requestsPaused;
  final bool statusBusy;
  final bool arriving;
  final VoidCallback onArrived;
  final VoidCallback onNavigate;
  final VoidCallback onOpenCommunication;
  final VoidCallback onCancelOrder;
  final VoidCallback onToggleRequests;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final String? farePill;
  final VoidCallback? onSafety;
  final bool showNearPickupAssist;

  void _openRouteDetails(BuildContext context, WidgetRef ref) {
    showDriverRideRouteDetailsSheet(
      context: context,
      colors: colors,
      typography: typography,
      destinationAddress: pickupAddress,
      farePill: farePill,
      riderName: riderName,
      navAppLabel: watchDriverNavAppLabel(ref),
      rideRequestId: rideId,
      smartPingPhase: DriverRideCommunicationPhase.enRouteToPickup,
      smartPingOnMyWayOnly: true,
      onContact: onOpenCommunication,
      onNavigate: onNavigate,
      onChangeNavigation: () => promptDriverNavAppChange(
        context: context,
        ref: ref,
      ),
      onCancelRide: onCancelOrder,
      onToggleRequests: onToggleRequests,
      requestsPaused: requestsPaused,
    );
  }

  Future<void> _handleToggleRequests(BuildContext context) async {
    if (!requestsPaused) {
      final themeColors = Theme.of(context).extension<HeyCabyColorTokens>();
      final themeTypo = Theme.of(context).extension<HeyCabyTypography>();
      if (themeColors == null || themeTypo == null) return;
      final confirmed = await showHeyCabyConfirmSheet(
        context,
        colors: themeColors,
        typography: themeTypo,
        title: DriverStrings.breakConfirmTitle,
        message: DriverStrings.breakConfirmBodyActiveRide,
        dismissLabel: DriverStrings.cancel,
        confirmLabel: DriverStrings.shiftStartBreak,
        icon: Icons.coffee_rounded,
      );
      if (confirmed != true) return;
    }
    onToggleRequests();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadMessages =
        ref.watch(driverRideUnreadMessageCountProvider(rideId));
    return DriverRideBoltScaffold(
      colors: colors,
      typography: typography,
      phase: DriverRideBoltPhase.enRoutePickup,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      driverLat: driverLat,
      driverLng: driverLng,
      onToggleRequests: () => _handleToggleRequests(context),
      onSafety: onSafety,
      onChat: onOpenCommunication,
      chatUnreadCount: unreadMessages,
      onNavigate: onNavigate,
      requestsPaused: requestsPaused,
      statusBusy: statusBusy,
      headerBanner: DriverTaxiTerugQueuedBannerSlot(
        currentRideId: rideId,
        colors: colors,
        typography: typography,
      ),
      infoCard: DriverRideBoltInfoCard(
        colors: colors,
        typography: typography,
        heroPrimary: DriverStrings.pickup,
        heroSecondary: null,
        focusAddress: pickupAddress,
        riderName: riderName,
        farePill: farePill,
        onOpenRouteDetails: () => _openRouteDetails(context, ref),
        onNavigate: onNavigate,
        navigateLabel: DriverStrings.startRideAndNavigate(
          watchDriverNavAppLabel(ref),
        ),
        navAppLabel: watchDriverNavAppLabel(ref),
        onCopyAddress: pickupAddress.trim().isEmpty
            ? null
            : () => copyDriverRideAddress(
                  context,
                  address: pickupAddress,
                  colors: colors,
                  typography: typography,
                ),
        assistBanner: showNearPickupAssist
            ? DriverStatusBadge(
                label: DriverStrings.nearPickupAssistBanner,
                colors: colors,
                typography: typography,
                tone: DriverStatusTone.success,
                icon: Icons.near_me_rounded,
              )
            : null,
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
