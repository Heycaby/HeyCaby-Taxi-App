import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ledger_flow_common.dart';
import 'driver_ping_history_section.dart';

/// Minimal completed-trip detail — route, fare breakdown, gated rider contact.
class DriverRideDetailBody extends StatelessWidget {
  const DriverRideDetailBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.errorMessage,
    required this.notFound,
    required this.dateLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupTimeLabel,
    required this.dropoffTimeLabel,
    required this.statsLabel,
    required this.fareLabel,
    required this.earningsLabel,
    required this.paymentMethodLabel,
    required this.platformFeeLabel,
    required this.showPlatformFee,
    required this.canContactRider,
    required this.rideRequestId,
    required this.onBack,
    this.onContactRider,
    this.onGetHelp,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? errorMessage;
  final bool notFound;
  final String dateLabel;
  final String statusLabel;
  final DriverStatusTone statusTone;
  final String pickupAddress;
  final String dropoffAddress;
  final String pickupTimeLabel;
  final String dropoffTimeLabel;
  final String? statsLabel;
  final String fareLabel;
  final String earningsLabel;
  final String paymentMethodLabel;
  final String platformFeeLabel;
  final bool showPlatformFee;
  final bool canContactRider;
  final String rideRequestId;
  final VoidCallback onBack;
  final VoidCallback? onContactRider;
  final VoidCallback? onGetHelp;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverLedgerFlowScaffold(
      title: DriverStrings.rideDetails,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(
              child: DriverSkeleton(colors: colors, width: 200, height: 24),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xxl),
                    child: Text(
                      errorMessage!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : notFound
                  ? DriverEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: DriverStrings.rideDetailsNotFound,
                      colors: colors,
                      typography: typography,
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        DriverSpacing.screenEdge,
                        DriverSpacing.md,
                        DriverSpacing.screenEdge,
                        bottomPad + DriverSpacing.lg,
                      ),
                      children: [
                        Text(
                          dateLabel,
                          style: typography.headlineSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: DriverSpacing.sm),
                        Row(
                          children: [
                            DriverStatusBadge(
                              label: statusLabel,
                              colors: colors,
                              typography: typography,
                              tone: statusTone,
                            ),
                            if (statsLabel != null) ...[
                              const SizedBox(width: DriverSpacing.md),
                              Expanded(
                                child: Text(
                                  statsLabel!,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: DriverSpacing.lg),
                        _RouteTimelineCard(
                          colors: colors,
                          typography: typography,
                          pickup: pickupAddress,
                          dropoff: dropoffAddress,
                          pickupTime: pickupTimeLabel,
                          dropoffTime: dropoffTimeLabel,
                        ),
                        const SizedBox(height: DriverSpacing.lg),
                        _BreakdownCard(
                          colors: colors,
                          typography: typography,
                          fareLabel: fareLabel,
                          earningsLabel: earningsLabel,
                          paymentMethodLabel: paymentMethodLabel,
                          platformFeeLabel: platformFeeLabel,
                          showPlatformFee: showPlatformFee,
                        ),
                        const SizedBox(height: DriverSpacing.lg),
                        if (canContactRider && onContactRider != null)
                          DriverButton(
                            label: DriverStrings.contactRider,
                            icon: Icons.chat_bubble_outline_rounded,
                            onPressed: onContactRider,
                            colors: colors,
                            typography: typography,
                          )
                        else if (!canContactRider)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DriverSpacing.md,
                              vertical: DriverSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: colors.backgroundAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.border.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              DriverStrings.rideDetailContactWindowClosed,
                              style: typography.bodySmall.copyWith(
                                color: colors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        if (onGetHelp != null) ...[
                          const SizedBox(height: DriverSpacing.sm),
                          DriverButton(
                            label: DriverStrings.rideDetailGetHelp,
                            icon: Icons.support_agent_outlined,
                            onPressed: onGetHelp,
                            colors: colors,
                            typography: typography,
                            variant: DriverButtonVariant.secondary,
                          ),
                        ],
                        const SizedBox(height: DriverSpacing.lg),
                        DriverPingHistorySection(
                          rideRequestId: rideRequestId,
                          colors: colors,
                          typography: typography,
                          initiallyExpanded: false,
                          collapsible: true,
                        ),
                      ],
                    ),
    );
  }
}

class _RouteTimelineCard extends StatelessWidget {
  const _RouteTimelineCard({
    required this.colors,
    required this.typography,
    required this.pickup,
    required this.dropoff,
    required this.pickupTime,
    required this.dropoffTime,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickup;
  final String dropoff;
  final String pickupTime;
  final String dropoffTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        children: [
          _RouteStop(
            colors: colors,
            typography: typography,
            dotColor: colors.primary,
            address: pickup,
            timeLabel: pickupTime,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 20,
                color: colors.border,
              ),
            ),
          ),
          _RouteStop(
            colors: colors,
            typography: typography,
            dotColor: colors.text,
            address: dropoff,
            timeLabel: dropoffTime,
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.colors,
    required this.typography,
    required this.dotColor,
    required this.address,
    required this.timeLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final Color dotColor;
  final String address;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: DriverSpacing.md),
        Expanded(
          child: Text(
            address,
            style: typography.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: DriverSpacing.sm),
        Text(
          timeLabel,
          style: typography.labelSmall.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.colors,
    required this.typography,
    required this.fareLabel,
    required this.earningsLabel,
    required this.paymentMethodLabel,
    required this.platformFeeLabel,
    required this.showPlatformFee,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String fareLabel;
  final String earningsLabel;
  final String paymentMethodLabel;
  final String platformFeeLabel;
  final bool showPlatformFee;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.rideDetailBreakdown,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          _MoneyRow(
            colors: colors,
            typography: typography,
            label: DriverStrings.rideDetailTripFare,
            value: fareLabel,
          ),
          const SizedBox(height: DriverSpacing.sm),
          _MoneyRow(
            colors: colors,
            typography: typography,
            label: DriverStrings.paymentMethod,
            value: paymentMethodLabel,
          ),
          if (showPlatformFee) ...[
            const SizedBox(height: DriverSpacing.sm),
            _MoneyRow(
              colors: colors,
              typography: typography,
              label: DriverStrings.platformFee,
              value: platformFeeLabel,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DriverSpacing.md),
            child: Divider(color: colors.border, height: 1),
          ),
          _MoneyRow(
            colors: colors,
            typography: typography,
            label: DriverStrings.driverEarnings,
            value: earningsLabel,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.colors,
    required this.typography,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize
        ? typography.labelLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          )
        : typography.bodySmall.copyWith(color: colors.textMuted);

    final valueStyle = emphasize
        ? typography.titleMedium.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          )
        : typography.bodyMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          );

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
