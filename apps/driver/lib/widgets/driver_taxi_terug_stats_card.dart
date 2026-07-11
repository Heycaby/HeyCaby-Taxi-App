import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_taxi_terug_stats.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_home_premium_style.dart';

/// Home card: Taxi Terug empty-km saved + earnings this month.
class DriverTaxiTerugStatsCard extends StatelessWidget {
  const DriverTaxiTerugStatsCard({
    super.key,
    required this.colors,
    required this.driverColors,
    required this.typo,
    required this.stats,
    this.loading = false,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final DriverTypography typo;
  final DriverTaxiTerugStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final monthRides = stats?.monthRides ?? 0;
    final monthKm = stats?.monthEmptyKmSaved ?? 0;
    final monthEuros = stats?.monthEarningsEuros ?? 0;
    final hasActivity = stats?.hasMonthActivity == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.55),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(
          color: colors.accent.withValues(alpha: hasActivity ? 0.35 : 0.18),
          width: 1.2,
        ),
        boxShadow: DriverHomePremiumStyle.tileShadow(driverColors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DriverRadius.md),
                ),
                child: Icon(
                  Icons.local_taxi_rounded,
                  color: colors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Text(
                  DriverStrings.taxiTerugStatsTitle,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          if (loading)
            Text(
              DriverStrings.loading,
              style: typo.bodySmall.copyWith(color: colors.textMid),
            )
          else if (!hasActivity)
            Text(
              DriverStrings.taxiTerugStatsEmpty,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: DriverStrings.taxiTerugStatsKmSaved,
                    value: DriverStrings.taxiTerugStatsKmValue(
                      stats!.formatKm(monthKm),
                    ),
                    colors: colors,
                    typo: typo,
                  ),
                ),
                const SizedBox(width: DriverSpacing.sm),
                Expanded(
                  child: _MetricBlock(
                    label: DriverStrings.taxiTerugStatsEarned,
                    value: stats!.formatEuros(monthEuros),
                    colors: colors,
                    typo: typo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DriverSpacing.xs),
            Text(
              DriverStrings.taxiTerugStatsRidesCount(monthRides),
              style: typo.labelSmall.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final DriverTypography typo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: typo.labelSmall.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: typo.titleMedium.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
