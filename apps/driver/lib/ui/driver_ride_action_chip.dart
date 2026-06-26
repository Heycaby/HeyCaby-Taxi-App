import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Ride-flow quick action — navigate, chat, cancel (48dp touch target).
class DriverRideActionChip extends StatelessWidget {
  const DriverRideActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.colors,
    required this.typography,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: colors.card,
      borderRadius: DriverRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.smAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: DriverSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: DriverRadius.smAll,
            border: Border.all(
              color: enabled ? colors.border : colors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? colors.primary : colors.textMuted,
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: typography.labelMedium.copyWith(
                    color: enabled ? colors.text : colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
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
