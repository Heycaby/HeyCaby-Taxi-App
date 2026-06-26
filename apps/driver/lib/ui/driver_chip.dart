import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

class DriverChip extends StatelessWidget {
  const DriverChip({
    super.key,
    required this.label,
    required this.colors,
    required this.typography,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final DriverColors colors;
  final DriverTypography typography;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? colors.primaryLight : colors.backgroundAlt;
    final fg = selected ? colors.primary : colors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(DriverRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.lg,
            vertical: DriverSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: DriverSpacing.xs),
              ],
              Text(
                label,
                style: typography.labelMedium.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
