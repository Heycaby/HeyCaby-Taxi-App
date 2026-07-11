import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_skeleton.dart';
import 'driver_opportunity_bolt_layout.dart';
import 'driver_ride_premium_style.dart';

/// **Opportunity Screen** presentation — accept / skip in &lt; 1 second.
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
    this.showCountdown = true,
    this.renderMap = true,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool showCountdown;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onErrorBack;
  final Map<String, dynamic>? rideData;
  final String? errorMessage;
  final bool renderMap;

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null && rideData != null) {
      return _OfferContent(
        colors: colors,
        typography: typography,
        countdownSeconds: countdownSeconds,
        totalCountdownSeconds: totalCountdownSeconds,
        showCountdown: showCountdown,
        rideData: rideData!,
        isAccepting: isAccepting,
        isDeclining: isDeclining,
        onAccept: onAccept,
        onDecline: onDecline,
        renderMap: renderMap,
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: DriverRidePremiumStyle.screenBackground(colors),
        ),
        child: SafeArea(
          bottom: false,
          child: errorMessage != null
              ? _ErrorState(
                  colors: colors,
                  typography: typography,
                  message: errorMessage!,
                  onBack: onErrorBack ?? onDecline,
                )
              : _LoadingState(colors: colors),
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
    required this.showCountdown,
    required this.rideData,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
    required this.renderMap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool showCountdown;
  final Map<String, dynamic> rideData;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool renderMap;

  @override
  Widget build(BuildContext context) {
    final offer = DriverOpportunityOfferData.from(rideData);

    return DriverOpportunityBoltLayout(
      colors: colors,
      typography: typography,
      offer: offer,
      countdownSeconds: countdownSeconds,
      totalCountdownSeconds: totalCountdownSeconds,
      showCountdown: showCountdown,
      isAccepting: isAccepting,
      isDeclining: isDeclining,
      onAccept: onAccept,
      onDecline: onDecline,
      renderMap: renderMap,
    );
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
          DriverSkeleton(
              colors: colors, width: 120, height: 120, borderRadius: 999),
          const SizedBox(height: DriverSpacing.xl),
          DriverSkeleton(colors: colors, height: 24),
          const SizedBox(height: DriverSpacing.md),
          DriverSkeleton(
              colors: colors, height: 140, borderRadius: DriverRadius.md),
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
