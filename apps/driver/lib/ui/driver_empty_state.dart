import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

class DriverEmptyState extends StatelessWidget {
  const DriverEmptyState({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    this.message,
    this.icon,
    this.action,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DriverSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, size: 48, color: colors.textMuted),
          const SizedBox(height: DriverSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.headlineSmall.copyWith(color: colors.text),
          ),
          if (message != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: DriverSpacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}
