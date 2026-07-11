import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

enum DriverStatusTone {
  online,
  offline,
  busy,
  success,
  warning,
  error,
  neutral
}

class DriverStatusBadge extends StatelessWidget {
  const DriverStatusBadge({
    super.key,
    required this.label,
    required this.colors,
    required this.typography,
    this.tone = DriverStatusTone.neutral,
    this.icon,
  });

  final String label;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _toneColors(colors);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: DriverSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: typography.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _toneColors(DriverColors colors) {
    switch (tone) {
      case DriverStatusTone.online:
      case DriverStatusTone.success:
        return (colors.primaryLight, colors.primary);
      case DriverStatusTone.offline:
      case DriverStatusTone.neutral:
        return (colors.backgroundAlt, colors.textSecondary);
      case DriverStatusTone.busy:
        return (colors.warning.withValues(alpha: 0.15), colors.warning);
      case DriverStatusTone.warning:
        return (colors.warning.withValues(alpha: 0.15), colors.warning);
      case DriverStatusTone.error:
        return (colors.error.withValues(alpha: 0.12), colors.error);
    }
  }
}
