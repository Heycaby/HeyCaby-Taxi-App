import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_card.dart';

class DriverStatisticCard extends StatelessWidget {
  const DriverStatisticCard({
    super.key,
    required this.colors,
    required this.typography,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: typography.labelMedium.copyWith(color: colors.textSecondary),
                ),
              ),
              if (icon != null) Icon(icon, size: 20, color: colors.primary),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            value,
            style: typography.numberMedium(colors),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DriverSpacing.xs),
            Text(
              subtitle!,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
