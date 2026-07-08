import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../utils/driver_address_clipboard.dart';
import '../l10n/driver_strings.dart';
import '../providers/driver_nav_app_pref_provider.dart';
import '../services/driver_nav_app_pref.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_bolt_layout.dart';
import 'driver_ride_flow_common.dart';

/// **Navigation Focus** — Bolt-style trip in progress.
class DriverNavigationFocusBody extends ConsumerWidget {
  const DriverNavigationFocusBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.riderName,
    required this.expectedAmountLabel,
    required this.completing,
    required this.onNavigate,
    required this.onCompleteRide,
    required this.onOpenCommunication,
    required this.onCancelRide,
    this.onToggleRequests,
    this.requestsPaused = false,
    this.statusBusy = false,
    this.showNearDestinationAssist = false,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
    this.etaLabel,
    this.onSafety,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final String? expectedAmountLabel;
  final bool completing;
  final VoidCallback onNavigate;
  final VoidCallback onCompleteRide;
  final VoidCallback onOpenCommunication;
  final VoidCallback onCancelRide;
  final VoidCallback? onToggleRequests;
  final bool requestsPaused;
  final bool statusBusy;
  final bool showNearDestinationAssist;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final String? etaLabel;
  final VoidCallback? onSafety;

  String _navLabel(WidgetRef ref) {
    final app = ref.watch(driverNavAppPrefProvider).valueOrNull ?? DriverNavApp.waze;
    return switch (app) {
      DriverNavApp.waze => 'Waze',
      DriverNavApp.google => 'Google Maps',
    };
  }

  void _openRouteDetails(BuildContext context, WidgetRef ref) {
    showDriverRideRouteDetailsSheet(
      context: context,
      colors: colors,
      typography: typography,
      destinationAddress: destinationAddress,
      farePill: driverRideBoltFarePill(expectedAmountLabel),
      riderName: riderName,
      navAppLabel: _navLabel(ref),
      onContact: onOpenCommunication,
      onNavigate: onNavigate,
      onCancelRide: onCancelRide,
      onToggleRequests: onToggleRequests,
      requestsPaused: requestsPaused,
    );
  }

  Future<void> _handleToggleRequests(BuildContext context) async {
    if (onToggleRequests == null) return;
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
    onToggleRequests!();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farePill = driverRideBoltFarePill(expectedAmountLabel);

    return DriverRideBoltScaffold(
      colors: colors,
      typography: typography,
      phase: DriverRideBoltPhase.inProgress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      driverLat: driverLat,
      driverLng: driverLng,
      onToggleRequests: onToggleRequests == null
          ? null
          : () => _handleToggleRequests(context),
      onSafety: onSafety,
      onChat: onOpenCommunication,
      onNavigate: onNavigate,
      requestsPaused: requestsPaused,
      statusBusy: statusBusy,
      infoCard: DriverRideBoltInfoCard(
        colors: colors,
        typography: typography,
        heroPrimary: etaLabel ?? DriverStrings.destination,
        heroSecondary: etaLabel != null ? null : null,
        focusAddress: destinationAddress,
        riderName: riderName,
        farePill: farePill,
        onOpenRouteDetails: () => _openRouteDetails(context, ref),
        onCopyAddress: destinationAddress.trim().isEmpty
            ? null
            : () => copyDriverRideAddress(
                  context,
                  address: destinationAddress,
                  colors: colors,
                  typography: typography,
                ),
        assistBanner: showNearDestinationAssist
            ? DriverStatusBadge(
                label: DriverStrings.nearDestinationAssistBanner,
                colors: colors,
                typography: typography,
                tone: DriverStatusTone.success,
                icon: Icons.flag_circle_outlined,
              )
            : null,
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.completeRide,
        primaryIcon: Icons.flag_rounded,
        onPrimary: completing ? null : onCompleteRide,
        primaryLoading: completing,
        primaryVariant: DriverButtonVariant.destructive,
      ),
    );
  }
}
