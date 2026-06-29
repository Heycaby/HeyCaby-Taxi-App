import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_earnings_modal_parts.dart';

/// Map overlay — today's earnings + online status at a glance.
class DriverEarningsChip extends StatelessWidget {
  const DriverEarningsChip({
    super.key,
    required this.todayEarnings,
    required this.statusLabel,
    required this.statusKind,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String todayEarnings;
  final String statusLabel;
  final DriverStatusKind statusKind;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (statusKind) {
      DriverStatusKind.online => colors.success,
      DriverStatusKind.onBreak => colors.warning,
      DriverStatusKind.offline => colors.textMuted,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        splashColor: colors.primary.withValues(alpha: 0.1),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DriverRadius.pill),
            color: colors.card.withValues(alpha: 0.97),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: DriverShadows.floating(colors),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.lg,
              vertical: DriverSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DriverAnimatedEarnings(
                  value: todayEarnings,
                  style: typography.titleLarge.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: DriverSpacing.sm),
                _StatusDot(color: statusColor, ring: colors.card),
                const SizedBox(width: DriverSpacing.sm),
                Flexible(
                  child: Text(
                    statusLabel,
                    style: typography.labelMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: DriverSpacing.xs),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
