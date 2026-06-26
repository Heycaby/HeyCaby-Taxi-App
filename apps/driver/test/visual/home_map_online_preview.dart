import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_radius.dart';
import 'package:heycaby_driver/theme/driver_shadows.dart';
import 'package:heycaby_driver/theme/driver_spacing.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_earnings_chip.dart';
import 'package:heycaby_driver/ui/driver_map_controls_column.dart';
import 'package:heycaby_driver/ui/driver_map_demand_chip.dart';
import 'package:heycaby_driver/ui/driver_map_eta_chip.dart';
import 'package:heycaby_driver/ui/driver_map_fab.dart';
import 'package:heycaby_driver/ui/driver_map_online_chip.dart';
import 'package:heycaby_driver/widgets/driver_earnings_modal_parts.dart';
import 'package:heycaby_driver/widgets/driver_money_dashboard_header.dart';

/// Online map chrome preview — M3 golden (no Mapbox / Riverpod).
class DriverMapOnlinePreview extends StatelessWidget {
  const DriverMapOnlinePreview({
    super.key,
    required this.colors,
    required this.typography,
    this.todayEarnings = '€124.50',
    this.todayRides = 6,
    this.sheetFraction = 0.38,
    this.waitingCount = 14,
    this.zoneName = 'Amsterdam Centrum',
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String todayEarnings;
  final int todayRides;
  final double sheetFraction;
  final int waitingCount;
  final String zoneName;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: DriverEarningsChip(
                    todayEarnings: todayEarnings,
                    statusLabel: DriverStrings.onlineSince,
                    statusKind: DriverStatusKind.online,
                    colors: colors,
                    typography: typography,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverMapOnlineChip(
                  zoneName: zoneName,
                  isOnBreak: false,
                  colors: colors,
                  typography: typography,
                  pulseLiveIndicator: false,
                  onTap: () {},
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverMapDemandChip(
                  zoneName: zoneName,
                  waitingCount: waitingCount,
                  highDemand: waitingCount >= 12,
                  colors: colors,
                  typography: typography,
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverMapEtaChip(
                  minutes: 8,
                  label: DriverStrings.mapEtaPickup,
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
          Positioned(
            top: topSafe + DriverSpacing.md,
            right: DriverSpacing.screenEdge,
            child: DriverMapControlsColumn(
              colors: colors,
              recenterIcon: Icons.my_location_rounded,
              onRecenter: () {},
              hubIcon: Icons.grid_view_rounded,
              hubBadge: 2,
              onHub: () {},
            ),
          ),
          Positioned(
            left: DriverSpacing.screenEdge,
            right: DriverSpacing.screenEdge,
            bottom: sheetHeight + DriverSpacing.md,
            child: _ShiftCardShell(
              colors: colors,
              typography: typography,
              todayEarnings: todayEarnings,
              rides: todayRides,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: sheetHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
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
                    const SizedBox(height: DriverSpacing.sm),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius:
                              BorderRadius.circular(DriverRadius.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    DriverMoneyDashboardHeader(
                      colors: colors,
                      typography: typography,
                      todayEarnings: todayEarnings,
                      todayRides: todayRides,
                      isOnline: true,
                    ),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: DriverRadius.mdAll,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        DriverStrings.online,
                        style: typography.labelLarge.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
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

class _ShiftCardShell extends StatelessWidget {
  const _ShiftCardShell({
    required this.colors,
    required this.typography,
    required this.todayEarnings,
    required this.rides,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String todayEarnings;
  final int rides;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.lgAll,
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.md),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                '2h',
                style: typography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(width: DriverSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverStrings.shiftWorkdayActive,
                    style: typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    '${DriverStrings.shiftTodaySummary}: $todayEarnings · $rides ${DriverStrings.rides}',
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
