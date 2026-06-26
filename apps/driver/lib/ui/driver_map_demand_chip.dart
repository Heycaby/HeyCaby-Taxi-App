import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Heat / demand hint — glanceable while driving.
class DriverMapDemandChip extends StatelessWidget {
  const DriverMapDemandChip({
    super.key,
    required this.zoneName,
    required this.waitingCount,
    required this.colors,
    required this.typography,
    this.highDemand = false,
  });

  final String zoneName;
  final int waitingCount;
  final DriverColors colors;
  final DriverTypography typography;
  final bool highDemand;

  @override
  Widget build(BuildContext context) {
    if (waitingCount < 1) return const SizedBox.shrink();

    final tint = highDemand ? colors.warning : colors.primary;
    final headline = highDemand
        ? DriverStrings.mapDemandHigh
        : DriverStrings.mapDemandActive;
    final detail = zoneName.isEmpty
        ? DriverStrings.mapDemandWaiting(waitingCount)
        : '${DriverStrings.mapDemandWaiting(waitingCount)} · $zoneName';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DriverRadius.pill),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
          boxShadow: DriverShadows.subtle(colors),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                highDemand
                    ? Icons.local_fire_department_rounded
                    : Icons.trending_up_rounded,
                size: 16,
                color: tint,
              ),
              const SizedBox(width: DriverSpacing.sm),
              Flexible(
                child: Text(
                  '$headline · $detail',
                  style: typography.labelMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
