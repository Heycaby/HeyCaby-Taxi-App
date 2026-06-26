import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import 'driver_ride_premium_style.dart';
import '../ui/driver_button.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_ride_card.dart';
import '../ui/driver_ride_countdown_ring.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_status_badge.dart';

/// **Opportunity Screen** presentation — accept / decline in &lt; 1 second.
class DriverOpportunityScreenBody extends StatelessWidget {
  const DriverOpportunityScreenBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
    this.onErrorBack,
    this.rideData,
    this.errorMessage,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onErrorBack;
  final Map<String, dynamic>? rideData;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: DriverStrings.newRideRequest,
        colors: colors,
        typography: typography,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.text),
          onPressed: isDeclining ? null : onDecline,
          tooltip: DriverStrings.decline,
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: DriverRidePremiumStyle.screenBackground(colors),
        ),
        child: errorMessage != null
            ? _ErrorState(
                colors: colors,
                typography: typography,
                message: errorMessage!,
                onBack: onErrorBack ?? onDecline,
              )
            : rideData == null
                ? _LoadingState(colors: colors)
                : _OfferContent(
                    colors: colors,
                    typography: typography,
                    countdownSeconds: countdownSeconds,
                    totalCountdownSeconds: totalCountdownSeconds,
                    rideData: rideData!,
                    isAccepting: isAccepting,
                    isDeclining: isDeclining,
                    onAccept: onAccept,
                    onDecline: onDecline,
                  ),
      ),
    );
  }
}

class _OfferContent extends StatelessWidget {
  const _OfferContent({
    required this.colors,
    required this.typography,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
    required this.rideData,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final Map<String, dynamic> rideData;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final riderName =
        rideData['pickup_contact_name'] as String? ?? DriverStrings.rider;
    final pickup = rideData['pickup_address'] as String? ?? '—';
    final destination = rideData['destination_address'] as String? ?? '—';
    final fare = _formatFare(rideData['offered_fare']);
    final distance = _formatDistance(rideData['estimated_distance_km']);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.screenEdge,
              DriverSpacing.md,
              DriverSpacing.screenEdge,
              DriverSpacing.lg,
            ),
            child: Column(
              children: [
                DriverStatusBadge(
                  label: DriverStrings.opportunityIncomingBadge,
                  colors: colors,
                  typography: typography,
                  tone: DriverStatusTone.warning,
                  icon: Icons.notifications_active_rounded,
                ).driverFadeSlideIn(staggerIndex: 0, slideY: -0.06),
                const SizedBox(height: DriverSpacing.lg),
                DriverRideCountdownRing(
                  secondsRemaining: countdownSeconds,
                  totalSeconds: totalCountdownSeconds,
                  colors: colors,
                  typography: typography,
                ).driverFadeSlideIn(staggerIndex: 0),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  DriverStrings.opportunityDecideFast,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).driverFadeSlideIn(staggerIndex: 1),
                const SizedBox(height: DriverSpacing.xl),
                Text(
                  riderName,
                  style: typography.headlineSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ).driverFadeSlideIn(staggerIndex: 2),
                const SizedBox(height: DriverSpacing.lg),
                DriverRideCard(
                  colors: colors,
                  typography: typography,
                  pickupLabel: pickup,
                  dropoffLabel: destination,
                  fareLabel: fare,
                  metaLabel: distance,
                  incomingPulse: true,
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DriverRadius.sheetTop,
            boxShadow: DriverShadows.floating(colors),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DriverSpacing.screenEdge,
              DriverSpacing.lg,
              DriverSpacing.screenEdge,
              DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DriverButton(
                  label: DriverStrings.accept,
                  icon: Icons.check_rounded,
                  onPressed: isAccepting ? null : onAccept,
                  loading: isAccepting,
                  size: DriverButtonSize.lg,
                  colors: colors,
                  typography: typography,
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverButton(
                  label: DriverStrings.decline,
                  onPressed: (isAccepting || isDeclining) ? null : onDecline,
                  loading: isDeclining,
                  variant: DriverButtonVariant.outline,
                  size: DriverButtonSize.md,
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _formatFare(dynamic raw) {
    if (raw is! num) return null;
    return '€${raw.toStringAsFixed(2)}';
  }

  String? _formatDistance(dynamic raw) {
    if (raw is! num) return null;
    return '${raw.toStringAsFixed(1)} km';
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.colors});

  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DriverSpacing.screenEdge),
      child: Column(
        children: [
          const SizedBox(height: DriverSpacing.xxl),
          DriverSkeleton(colors: colors, width: 120, height: 120, borderRadius: 999),
          const SizedBox(height: DriverSpacing.xl),
          DriverSkeleton(colors: colors, height: 24),
          const SizedBox(height: DriverSpacing.md),
          DriverSkeleton(colors: colors, height: 140, borderRadius: DriverRadius.md),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.colors,
    required this.typography,
    required this.message,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DriverEmptyState(
        title: DriverStrings.rideNotFound,
        message: message,
        icon: Icons.error_outline_rounded,
        colors: colors,
        typography: typography,
        action: DriverButton(
          label: DriverStrings.back,
          onPressed: onBack,
          colors: colors,
          typography: typography,
          variant: DriverButtonVariant.outline,
          expanded: false,
        ),
      ),
    );
  }
}
