import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_premium_style.dart';
import 'driver_status_badge.dart';

/// Incoming / active ride summary card.
class DriverRideCard extends StatelessWidget {
  const DriverRideCard({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.fareLabel,
    this.metaLabel,
    this.statusLabel,
    this.statusTone = DriverStatusTone.neutral,
    this.onTap,
    this.trailing,
    this.incomingPulse = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupLabel;
  final String dropoffLabel;
  final String? fareLabel;
  final String? metaLabel;
  final String? statusLabel;
  final DriverStatusTone statusTone;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool incomingPulse;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.lgAll,
        child: Ink(
          decoration: DriverRidePremiumStyle.frostedFill(
            colors,
            borderRadius: DriverRadius.lgAll,
            tint: colors.card,
            tintOpacity: 0.62,
          ),
          padding: const EdgeInsets.all(DriverSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusLabel != null)
                    DriverStatusBadge(
                      label: statusLabel!,
                      colors: colors,
                      typography: typography,
                      tone: statusTone,
                    ),
                  const Spacer(),
                  if (fareLabel != null)
                    Text(
                      fareLabel!,
                      style: typography.numberMedium(colors),
                      textAlign: TextAlign.right,
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: DriverSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: DriverSpacing.lg),
              _RouteLine(
                colors: colors,
                typography: typography,
                pickupLabel: pickupLabel,
                dropoffLabel: dropoffLabel,
              ),
              if (metaLabel != null) ...[
                const SizedBox(height: DriverSpacing.md),
                Text(
                  metaLabel!,
                  style: typography.bodySmall.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return incomingPulse
        ? card.driverRideIncomingPulse().driverFadeSlideIn(staggerIndex: 1)
        : card;
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.colors,
    required this.typography,
    required this.pickupLabel,
    required this.dropoffLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupLabel;
  final String dropoffLabel;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              _RouteDot(color: colors.primary),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: colors.border,
                ),
              ),
              _RouteDot(color: colors.text),
            ],
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickupLabel,
                  style: typography.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DriverSpacing.md),
                Text(
                  dropoffLabel,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.25,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
