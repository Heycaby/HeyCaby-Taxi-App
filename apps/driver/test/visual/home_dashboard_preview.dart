import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_radius.dart';
import 'package:heycaby_driver/theme/driver_shadows.dart';
import 'package:heycaby_driver/theme/driver_spacing.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_earnings_chip.dart';
import 'package:heycaby_driver/ui/driver_map_fab.dart';
import 'package:heycaby_driver/widgets/driver_earnings_modal_parts.dart';
import 'package:heycaby_driver/widgets/driver_home_premium_style.dart';
import 'package:heycaby_driver/ui/driver_accent_rail_card.dart';

/// Map + chrome preview for golden tests (no Mapbox).
class DriverMoneyDashboardPreview extends StatelessWidget {
  const DriverMoneyDashboardPreview({
    super.key,
    required this.colors,
    required this.typography,
    this.todayEarnings = '€124.50',
    this.todayRides = 6,
    this.sheetFraction = 0.42,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String todayEarnings;
  final int todayRides;
  final double sheetFraction;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final sheetHeight = height * sheetFraction;
    const topSafe = 59.0;

    return ColoredBox(
      color: colors.backgroundAlt,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _MapGridPainter(colors),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: topSafe + DriverSpacing.sm,
            left: DriverSpacing.md,
            child: DriverMapFab(
              icon: Icons.menu_rounded,
              colors: colors,
              onTap: () {},
            ),
          ),
          Positioned(
            top: topSafe + DriverSpacing.sm,
            left: DriverSpacing.screenEdge,
            right: DriverSpacing.screenEdge,
            child: Center(
              child: DriverEarningsChip(
                todayEarnings: todayEarnings,
                statusLabel: DriverStrings.offline,
                statusKind: DriverStatusKind.offline,
                colors: colors,
                typography: typography,
                onTap: () {},
              ),
            ),
          ),
          Positioned(
            top: topSafe + DriverSpacing.md,
            right: DriverSpacing.screenEdge,
            child: DriverMapFab(
              icon: Icons.my_location_rounded,
              colors: colors,
              onTap: () {},
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: sheetHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: DriverHomePremiumStyle.sheetTopGradient,
                borderRadius: DriverRadius.sheetTop,
                boxShadow: DriverShadows.floating(colors),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DriverSpacing.screenEdge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DriverHomeSheetHandle(colors: colors),
                    Text(
                      DriverStrings.homeLiveRidesTitle.toUpperCase(),
                      style: typography.labelSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    DriverAccentRailCard(
                      colors: colors,
                      padding: const EdgeInsets.all(DriverSpacing.lg),
                      child: Row(
                        children: [
                          DriverHomeIconOrb(
                            icon: Icons.radar_rounded,
                            colors: colors,
                            size: 44,
                            iconSize: 22,
                          ),
                          const SizedBox(width: DriverSpacing.md),
                          Expanded(
                            child: Text(
                              DriverStrings.homeNoLiveRidesOffline,
                              style: typography.bodyMedium.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    Container(
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(29),
                        gradient: LinearGradient(
                          colors: [
                            colors.error.withValues(alpha: 0.08),
                            colors.warning.withValues(alpha: 0.06),
                            colors.success.withValues(alpha: 0.10),
                          ],
                        ),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.error.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.error.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter(this.colors);

  final DriverColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}
