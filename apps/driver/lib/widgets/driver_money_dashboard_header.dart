import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_home_premium_style.dart';

/// Money Dashboard sheet header — premium earnings hero + status.
class DriverMoneyDashboardHeader extends StatelessWidget {
  const DriverMoneyDashboardHeader({
    super.key,
    required this.colors,
    required this.typography,
    required this.todayEarnings,
    required this.todayRides,
    required this.isOnline,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String todayEarnings;
  final int todayRides;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final ridesLabel = DriverStrings.homeTodayRidesCount(todayRides);

    return Container(
      margin: const EdgeInsets.only(bottom: DriverSpacing.lg),
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.lg,
        DriverSpacing.lg,
        DriverSpacing.lg,
        DriverSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: DriverHomePremiumStyle.heroGradient(colors),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
        boxShadow: DriverHomePremiumStyle.heroGlow(colors),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -24,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.12),
                      colors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DriverStrings.today.toUpperCase(),
                          style: typography.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: DriverSpacing.sm),
                        DriverAnimatedEarnings(
                          value: todayEarnings,
                          style: typography.displayMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            letterSpacing: 0,
                            height: 1.0,
                            fontSize: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DriverOnlineStatusBadge(
                    isOnline: isOnline,
                    colors: colors,
                    typography: typography,
                  ),
                ],
              ),
              const SizedBox(height: DriverSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DriverSpacing.md,
                  vertical: DriverSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.background.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(DriverRadius.pill),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_taxi_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ridesLabel,
                      style: typography.labelLarge.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
