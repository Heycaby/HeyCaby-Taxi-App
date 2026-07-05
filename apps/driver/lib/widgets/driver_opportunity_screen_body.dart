import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_ride_premium_style.dart';
import '../ui/driver_button.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_flow_common.dart';

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
    if (errorMessage == null && rideData != null) {
      return _OfferContent(
        colors: colors,
        typography: typography,
        countdownSeconds: countdownSeconds,
        totalCountdownSeconds: totalCountdownSeconds,
        rideData: rideData!,
        isAccepting: isAccepting,
        isDeclining: isDeclining,
        onAccept: onAccept,
        onDecline: onDecline,
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
    final offer = _RideOfferViewData.from(rideData);

    return DriverRideFlowScaffold(
      title: DriverStrings.newRideRequest,
      colors: colors,
      typography: typography,
      onBack: isDeclining ? null : onDecline,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DecisionHero(
            colors: colors,
            typography: typography,
            offer: offer,
            countdownSeconds: countdownSeconds,
            totalCountdownSeconds: totalCountdownSeconds,
          ).driverFadeSlideIn(staggerIndex: 0, slideY: -0.04),
          const SizedBox(height: DriverSpacing.md),
          _RouteDecisionCard(
            colors: colors,
            typography: typography,
            offer: offer,
          ).driverFadeSlideIn(staggerIndex: 1),
        ],
      ),
      bottomBar: _OpportunityDecisionBar(
        colors: colors,
        typography: typography,
        isAccepting: isAccepting,
        isDeclining: isDeclining,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }
}

class _OpportunityDecisionBar extends StatelessWidget {
  const _OpportunityDecisionBar({
    required this.colors,
    required this.typography,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.sheetTop,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DriverRidePremiumStyle.sheetHandle(colors),
            const SizedBox(height: DriverSpacing.md),
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
            const SizedBox(height: DriverSpacing.sm),
            Text(
              DriverStrings.incomingRideSkipHint,
              textAlign: TextAlign.center,
              style: typography.bodySmall.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionHero extends StatelessWidget {
  const _DecisionHero({
    required this.colors,
    required this.typography,
    required this.offer,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final _RideOfferViewData offer;
  final int countdownSeconds;
  final int totalCountdownSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = totalCountdownSeconds <= 0
        ? 0.0
        : (countdownSeconds / totalCountdownSeconds).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
        boxShadow: DriverShadows.card(colors),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DriverStatusBadge(
                  label: DriverStrings.opportunityIncomingBadge,
                  colors: colors,
                  typography: typography,
                  tone: DriverStatusTone.warning,
                  icon: Icons.notifications_active_rounded,
                ),
                const Spacer(),
                _CountdownPill(
                  colors: colors,
                  typography: typography,
                  seconds: countdownSeconds,
                ),
              ],
            ),
            const SizedBox(height: DriverSpacing.lg),
            Text(
              DriverStrings.incomingRideEstimatedEarnings,
              style: typography.labelLarge.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DriverSpacing.xs),
            Text(
              offer.fareLabel ?? DriverStrings.incomingRideOpenFare,
              style: typography.displaySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: DriverSpacing.xs),
            Text(
              DriverStrings.incomingRideReviewTrip,
              style: typography.bodyLarge.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: colors.backgroundAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  countdownSeconds <= 8 ? colors.warning : colors.primary,
                ),
              ),
            ),
            const SizedBox(height: DriverSpacing.lg),
            Wrap(
              spacing: DriverSpacing.sm,
              runSpacing: DriverSpacing.sm,
              children: [
                _MetricChip(
                  colors: colors,
                  typography: typography,
                  icon: Icons.person_rounded,
                  label: offer.riderLabel,
                ),
                if (offer.ratingLabel != null)
                  _MetricChip(
                    colors: colors,
                    typography: typography,
                    icon: Icons.star_rounded,
                    label: offer.ratingLabel!,
                  ),
                if (offer.paymentLabel != null)
                  _MetricChip(
                    colors: colors,
                    typography: typography,
                    icon: Icons.credit_card_rounded,
                    label: offer.paymentLabel!,
                  ),
                if (offer.demandLabel != null)
                  _MetricChip(
                    colors: colors,
                    typography: typography,
                    icon: Icons.trending_up_rounded,
                    label: offer.demandLabel!,
                    highlighted: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({
    required this.colors,
    required this.typography,
    required this.seconds,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_rounded,
            size: 18,
            color: seconds <= 8 ? colors.warning : colors.primary,
          ),
          const SizedBox(width: DriverSpacing.xs),
          Text(
            '${seconds}s',
            style: typography.labelLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDecisionCard extends StatelessWidget {
  const _RouteDecisionCard({
    required this.colors,
    required this.typography,
    required this.offer,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final _RideOfferViewData offer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.lgAll,
        border: Border.all(color: colors.border),
        boxShadow: DriverShadows.card(colors),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DriverStrings.incomingRideRoute,
              style: typography.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: DriverSpacing.md),
            _RoutePreview(
              colors: colors,
              typography: typography,
              pickupLabel: offer.pickupShortLabel,
              destinationLabel: offer.destinationShortLabel,
            ),
            const SizedBox(height: DriverSpacing.lg),
            _RouteStopRow(
              colors: colors,
              typography: typography,
              dotColor: colors.primary,
              title: DriverStrings.incomingRidePickup,
              address: offer.pickupAddress,
              meta: offer.pickupMeta,
              showConnector: true,
            ),
            _RouteStopRow(
              colors: colors,
              typography: typography,
              dotColor: colors.error,
              title: DriverStrings.incomingRideDropoff,
              address: offer.destinationAddress,
              meta: offer.tripMeta,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStopRow extends StatelessWidget {
  const _RouteStopRow({
    required this.colors,
    required this.typography,
    required this.dotColor,
    required this.title,
    required this.address,
    this.meta,
    this.showConnector = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final Color dotColor;
  final String title;
  final String address;
  final String? meta;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.card, width: 3),
                  boxShadow: DriverShadows.subtle(colors),
                ),
              ),
              if (showConnector)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: colors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: showConnector ? DriverSpacing.lg : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: typography.labelMedium.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (meta != null)
                        Text(
                          meta!,
                          style: typography.labelLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: DriverSpacing.xs),
                  Text(
                    address,
                    style: typography.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({
    required this.colors,
    required this.typography,
    required this.pickupLabel,
    required this.destinationLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupLabel;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DriverSpacing.md),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: DriverRadius.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.incomingRideRoutePreview,
            style: typography.labelMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              _RoutePreviewNode(
                colors: colors,
                typography: typography,
                color: colors.primary,
                label: pickupLabel,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              _RoutePreviewNode(
                colors: colors,
                typography: typography,
                color: colors.error,
                label: destinationLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutePreviewNode extends StatelessWidget {
  const _RoutePreviewNode({
    required this.colors,
    required this.typography,
    required this.color,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: colors.card, width: 2),
            ),
          ),
          const SizedBox(width: DriverSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.colors,
    required this.typography,
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.success.withValues(alpha: 0.12)
            : colors.backgroundAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? colors.success.withValues(alpha: 0.28)
              : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: highlighted ? colors.success : colors.textSecondary,
          ),
          const SizedBox(width: DriverSpacing.xs),
          Text(
            label,
            style: typography.labelLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideOfferViewData {
  const _RideOfferViewData({
    required this.riderLabel,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupShortLabel,
    required this.destinationShortLabel,
    this.fareLabel,
    this.ratingLabel,
    this.paymentLabel,
    this.demandLabel,
    this.pickupMeta,
    this.tripMeta,
  });

  final String riderLabel;
  final String pickupAddress;
  final String destinationAddress;
  final String pickupShortLabel;
  final String destinationShortLabel;
  final String? fareLabel;
  final String? ratingLabel;
  final String? paymentLabel;
  final String? demandLabel;
  final String? pickupMeta;
  final String? tripMeta;

  factory _RideOfferViewData.from(Map<String, dynamic> data) {
    final riderName = _firstText(data, const [
          'pickup_contact_name',
          'rider_name',
          'customer_name',
          'passenger_name',
        ]) ??
        DriverStrings.rider;
    final pickup = _firstText(data, const [
          'pickup_address',
          'origin_address',
          'from_address',
        ]) ??
        '—';
    final destination = _firstText(data, const [
          'destination_address',
          'dropoff_address',
          'to_address',
        ]) ??
        '—';
    final pickupMinutes = _firstNum(data, const [
      'pickup_eta_min',
      'pickup_eta_minutes',
      'estimated_pickup_minutes',
      'driver_pickup_minutes',
    ]);
    final pickupDistance = _firstNum(data, const [
      'pickup_distance_km',
      'distance_to_pickup_km',
      'driver_distance_km',
    ]);
    final tripMinutes = _firstNum(data, const [
      'estimated_duration_min',
      'duration_min',
      'estimated_trip_duration_min',
      'trip_duration_min',
    ]);
    final tripDistance = _firstNum(data, const [
      'estimated_distance_km',
      'distance_km',
      'trip_distance_km',
    ]);
    final rating = _firstNum(data, const [
      'rider_rating',
      'rider_score',
      'rider_average_rating',
    ]);
    final demand = _firstNum(data, const [
      'surge_multiplier',
      'demand_multiplier',
      'price_multiplier',
    ]);

    return _RideOfferViewData(
      riderLabel: riderName,
      pickupAddress: pickup,
      destinationAddress: destination,
      pickupShortLabel: _shortPlaceLabel(pickup),
      destinationShortLabel: _shortPlaceLabel(destination),
      fareLabel: _fareLabel(_firstNum(data, const [
        'offered_fare',
        'estimated_fare',
        'quoted_fare',
        'fare',
        'price',
      ])),
      ratingLabel: rating?.toStringAsFixed(1),
      paymentLabel: _paymentLabelFromData(data),
      demandLabel: demand == null || demand <= 1
          ? null
          : '${demand.toStringAsFixed(1)}x ${DriverStrings.incomingRideDemand}',
      pickupMeta: _joinMeta([
        _minutesLabel(pickupMinutes),
        _distanceLabel(pickupDistance),
      ]),
      tripMeta: _joinMeta([
        _minutesLabel(tripMinutes),
        _distanceLabel(tripDistance),
      ]),
    );
  }

  static String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static double? _firstNum(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _fareLabel(double? value) {
    if (value == null) return null;
    return '€${value.toStringAsFixed(2)}';
  }

  static String? _minutesLabel(double? value) {
    if (value == null) return null;
    return '${value.round()} min';
  }

  static String? _distanceLabel(double? value) {
    if (value == null) return null;
    return '${value.toStringAsFixed(1)} km';
  }

  static String? _joinMeta(List<String?> parts) {
    final visible = parts.whereType<String>().toList(growable: false);
    if (visible.isEmpty) return null;
    return visible.join(' · ');
  }

  static String _shortPlaceLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '—') return '—';
    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return trimmed;
    return parts.first;
  }

  static String? _paymentLabelFromData(Map<String, dynamic> data) {
    final methods = _paymentMethods(data);
    if (methods.length > 1) return DriverStrings.incomingRidePaymentFlexible;
    if (methods.length == 1) return _paymentLabel(methods.first);
    return _paymentLabel(_firstText(data, const [
      'payment_method',
      'preferred_payment_method',
      'payment_type',
    ]));
  }

  static List<String> _paymentMethods(Map<String, dynamic> data) {
    for (final key in const [
      'payment_methods',
      'accepted_payment_methods',
      'preferred_payment_methods',
    ]) {
      final value = data[key];
      if (value is List) {
        return value
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toSet()
            .toList(growable: false);
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'[,|/]'))
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toSet()
            .toList(growable: false);
      }
    }
    return const [];
  }

  static String? _paymentLabel(String? raw) {
    if (raw == null) return null;
    final normalized = raw.toLowerCase().replaceAll('_', ' ');
    if (normalized.contains('cash') || normalized.contains('contant')) {
      return DriverStrings.paymentCash;
    }
    if (normalized.contains('card') || normalized.contains('pin')) {
      return DriverStrings.paymentCard;
    }
    if (normalized.contains('invoice') || normalized.contains('factuur')) {
      return DriverStrings.paymentInvoice;
    }
    if (normalized.contains('tikkie')) return 'Tikkie';
    return raw;
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
