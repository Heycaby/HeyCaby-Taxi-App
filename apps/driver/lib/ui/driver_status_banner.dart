import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

enum DriverStatusBannerTone { success, error, info }

/// Inline status for forms — success, error, or neutral info.
class DriverStatusBanner extends StatelessWidget {
  const DriverStatusBanner({
    super.key,
    required this.message,
    required this.colors,
    required this.typography,
    this.tone = DriverStatusBannerTone.info,
  });

  final String message;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverStatusBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final tint = switch (tone) {
      DriverStatusBannerTone.success => colors.primary,
      DriverStatusBannerTone.error => colors.error,
      DriverStatusBannerTone.info => colors.textSecondary,
    };
    final icon = switch (tone) {
      DriverStatusBannerTone.success => Icons.check_circle_rounded,
      DriverStatusBannerTone.error => Icons.error_outline_rounded,
      DriverStatusBannerTone.info => Icons.info_outline_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: DriverRadius.smAll,
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tint, size: 20),
            const SizedBox(width: DriverSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: typography.bodyMedium.copyWith(
                  color: tone == DriverStatusBannerTone.error
                      ? colors.error
                      : colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
