import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_taxi_terug_stats.dart';
import '../providers/driver_taxi_terug_stats_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// One-line Taxi Terug month summary for My rides (Supabase [fn_driver_taxi_terug_stats]).
class DriverMyRidesTaxiTerugSummary extends ConsumerWidget {
  const DriverMyRidesTaxiTerugSummary({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(driverTaxiTerugStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats == null || !stats.hasMonthActivity) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.sm,
            DriverSpacing.screenEdge,
            DriverSpacing.xs,
          ),
          child: _SummaryLine(
            colors: colors,
            typography: typography,
            stats: stats,
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.sm,
          DriverSpacing.screenEdge,
          DriverSpacing.xs,
        ),
        child: Text(
          DriverStrings.loading,
          style: typography.bodySmall.copyWith(color: colors.textMuted),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.colors,
    required this.typography,
    required this.stats,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverTaxiTerugStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.primaryLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(DriverRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_taxi_rounded,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Text(
              DriverStrings.myRidesTaxiTerugMonthSummary(
                rides: stats.monthRides,
                km: stats.formatKm(stats.monthEmptyKmSaved),
                euros: stats.formatEuros(stats.monthEarningsEuros),
              ),
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
