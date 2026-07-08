import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../utils/driver_address_clipboard.dart';
import '../l10n/driver_strings.dart';
import '../providers/driver_nav_app_pref_provider.dart';
import '../services/driver_nav_app_pref.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import 'driver_ride_bolt_layout.dart';
import 'driver_ride_flow_common.dart';

/// **Pickup Arrival** — Bolt-style waiting at pickup; start trip friction-free.
class DriverPickupArrivalBody extends ConsumerWidget {
  const DriverPickupArrivalBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.rideId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.riderName,
    required this.waitSeconds,
    required this.waitingGraceSeconds,
    required this.waitingRatePerMinute,
    required this.waitingFeeWaived,
    required this.canReportNoShow,
    required this.loading,
    required this.onStartRide,
    required this.onOpenCommunication,
    required this.onNavigate,
    required this.onWaiveWaitingFee,
    required this.onReportNoShow,
    required this.onCancelRide,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
    this.farePill,
    this.onToggleRequests,
    this.onSafety,
    this.requestsPaused = false,
    this.statusBusy = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String rideId;
  final String pickupAddress;
  final String destinationAddress;
  final String? riderName;
  final int waitSeconds;
  final int waitingGraceSeconds;
  final double waitingRatePerMinute;
  final bool waitingFeeWaived;
  final bool canReportNoShow;
  final bool loading;
  final VoidCallback onStartRide;
  final VoidCallback onOpenCommunication;
  final VoidCallback onNavigate;
  final VoidCallback onWaiveWaitingFee;
  final VoidCallback onReportNoShow;
  final VoidCallback onCancelRide;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final String? farePill;
  final VoidCallback? onToggleRequests;
  final VoidCallback? onSafety;
  final bool requestsPaused;
  final bool statusBusy;

  String _navLabel(WidgetRef ref) {
    final app =
        ref.watch(driverNavAppPrefProvider).valueOrNull ?? DriverNavApp.waze;
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
      farePill: farePill,
      riderName: riderName,
      navAppLabel: _navLabel(ref),
      rideRequestId: rideId,
      smartPingPhase: DriverRideCommunicationPhase.atPickup,
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
    return DriverRideBoltScaffold(
      colors: colors,
      typography: typography,
      phase: DriverRideBoltPhase.atPickup,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      driverLat: driverLat,
      driverLng: driverLng,
      showWaitHereHint: true,
      onToggleRequests: onToggleRequests == null
          ? null
          : () => _handleToggleRequests(context),
      onSafety: onSafety,
      onChat: onOpenCommunication,
      requestsPaused: requestsPaused,
      statusBusy: statusBusy,
      infoCard: DriverRideBoltInfoCard(
        colors: colors,
        typography: typography,
        heroPrimary: driverRideBoltWaitLabel(waitSeconds),
        heroSecondary: DriverStrings.waiting,
        focusAddress: pickupAddress,
        riderName: riderName,
        farePill: farePill,
        onOpenRouteDetails: () => _openRouteDetails(context, ref),
        onCopyAddress: pickupAddress.trim().isEmpty
            ? null
            : () => copyDriverRideAddress(
                  context,
                  address: pickupAddress,
                  colors: colors,
                  typography: typography,
                ),
        extra: _WaitingFeeCard(
          colors: colors,
          typography: typography,
          waitSeconds: waitSeconds,
          graceSeconds: waitingGraceSeconds,
          ratePerMinute: waitingRatePerMinute,
          waived: waitingFeeWaived,
          loading: loading,
          onWaive: onWaiveWaitingFee,
        ),
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: DriverStrings.startRideAndNavigate(_navLabel(ref)),
        primaryIcon: Icons.navigation_rounded,
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
        ? DriverStrings.waitingFeeWaivedTitle
        : inGrace
            ? DriverStrings.waitingFeeFreeTimeTitle
            : DriverStrings.waitingFeeLabel;
    final mainValue = waived
        ? _money(0)
        : inGrace
            ? _duration(_remainingGraceSeconds)
            : _duration(_chargeableSeconds);
    final subtitle = waived
        ? DriverStrings.waitingFeeWaivedBody
        : inGrace
            ? DriverStrings.waitingFeeFreeTimeBody
            : '${_money(_feeCents)} ${DriverStrings.waitingFeeAddedSoFar}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.backgroundAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainValue,
            style: typography.titleLarge.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          if (!waived && _feeCents > 0)
            TextButton(
              onPressed: loading ? null : onWaive,
              child: Text(DriverStrings.waitingFeeWaiveAction),
            ),
        ],
      ),
    );
  }
}
