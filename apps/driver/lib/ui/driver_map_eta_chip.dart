import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// ETA display for map overlays — pickup, dropoff, or navigation legs.
class DriverMapEtaChip extends StatelessWidget {
  const DriverMapEtaChip({
    super.key,
    required this.minutes,
    required this.label,
    required this.colors,
    required this.typography,
    this.icon = Icons.schedule_rounded,
  });

  final int minutes;
  final String label;
  final DriverColors colors;
  final DriverTypography typography;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        border: Border.all(color: colors.border),
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DriverSpacing.md,
          vertical: DriverSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: DriverSpacing.sm),
            Text(
              label,
              style: typography.labelMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: DriverSpacing.sm),
            Text(
              DriverStrings.mapEtaMinutes(minutes),
              style: typography.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
