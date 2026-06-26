import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import 'scheduled_preride_actions.dart';

enum WorkSubTab { earnings, availableRides }
enum RideFilter { now, scheduled, marketplace }

/// **Shift Command** — earnings + available rides without leaving map mental model.
class DriverShiftCommandBody extends ConsumerWidget {
  const DriverShiftCommandBody({
    super.key,
    required this.subTab,
    required this.rideFilter,
    required this.onSubTabChange,
    required this.onFilterChange,
    required this.onBack,
  });

  final WorkSubTab subTab;
  final RideFilter rideFilter;
  final ValueChanged<WorkSubTab> onSubTabChange;
  final ValueChanged<RideFilter> onFilterChange;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColors = ref.watch(colorsProvider);
    final themeTypo = ref.watch(typographyProvider);
    final colors = DriverColors.fromTheme(themeColors);
    final typography = DriverTypography.fromTheme(themeTypo);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: '',
        colors: colors,
        typography: typography,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SubTabBar(
              subTab: subTab,
              colors: themeColors,
              typo: themeTypo,
              driverColors: colors,
              driverTypography: typography,
              onSelect: onSubTabChange,
            ),
            Expanded(
              child: subTab == WorkSubTab.earnings
                  ? _EarningsContent(colors: themeColors, typo: themeTypo)
                  : _AvailableRidesContent(
                      filter: rideFilter,
                      colors: themeColors,
                      typo: themeTypo,
                      onFilterChange: onFilterChange,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubTabBar extends StatelessWidget {
  final WorkSubTab subTab;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverColors driverColors;
  final DriverTypography driverTypography;
  final void Function(WorkSubTab) onSelect;

  const _SubTabBar({
    required this.subTab,
    required this.colors,
    required this.typo,
    required this.driverColors,
    required this.driverTypography,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Pill(
              label: DriverStrings.earnings,
              isSelected: subTab == WorkSubTab.earnings,
              colors: driverColors,
              typography: driverTypography,
              onTap: () => onSelect(WorkSubTab.earnings),
            ),
          ),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: _Pill(
              label: DriverStrings.availableRides,
              isSelected: subTab == WorkSubTab.availableRides,
              colors: driverColors,
              typography: driverTypography,
              onTap: () => onSelect(WorkSubTab.availableRides),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: DriverSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : colors.backgroundAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.border : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: typography.bodyMedium.copyWith(
            color: isSelected ? colors.text : colors.textMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EarningsContent extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _EarningsContent({required this.colors, required this.typo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(driverEarningsProvider);
    final ridesAsync = ref.watch(todayRidesProvider);

    return earningsAsync.when(
      data: (summary) {
        final todayStr = summary != null
            ? summary.formatEuros(summary.todayEuros)
            : '€0.00';
        final weekRides = summary?.weekRides ?? 0;
        final weekStr = summary != null
            ? summary.formatEuros(summary.weekEuros)
            : '€0.00';
        final avgPerRide = (summary != null && weekRides > 0)
            ? summary.weekEuros / weekRides
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.accent.withValues(alpha: 0.16),
                      colors.card,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.payments_outlined, color: colors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.today,
                            style: typo.labelLarge.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            todayStr,
                            style: typo.displayMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.ridesThisWeek,
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$weekRides',
                            style: typo.titleMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.thisWeek,
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weekStr,
                            style: typo.titleMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border.withValues(alpha: 0.9)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: colors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${DriverStrings.avgPerRide}: €${avgPerRide.toStringAsFixed(2)}',
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _WeeklyEarningsChart(
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 24),
              Text(
                DriverStrings.todaysRides,
                style: typo.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ridesAsync.when(
                data: (rides) {
                  if (rides.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        'No rides completed yet today.',
                        style: typo.bodyMedium.copyWith(color: colors.textSoft),
                      ),
                    );
                  }
                  return Column(
                    children: rides
                        .map((r) => _TodayRideTile(ride: r, colors: colors, typo: typo))
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          DriverStrings.couldNotLoadEarnings,
          style: typo.bodyMedium.copyWith(color: colors.textSoft),
        ),
      ),
    );
  }
}

class _WeeklyEarningsChart extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _WeeklyEarningsChart({
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(weeklyDailyEarningsProvider);
    return dailyAsync.when(
      data: (daily) {
        final maxVal = daily.isEmpty ? 1.0 : daily.reduce((a, b) => a > b ? a : b);
        final maxY = maxVal > 0 ? maxVal * 1.2 : 10.0;
        final dayLabels = [
          for (var i = -6; i <= 0; i++)
            DateFormat('E').format(DateTime.now().add(Duration(days: i))).substring(0, 1),
        ];
        final spots = daily.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
        return Container(
          height: 186,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DriverStrings.thisWeek,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) => Text(
                            dayLabels[v.toInt().clamp(0, dayLabels.length - 1)],
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          reservedSize: 20,
                          interval: 1,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) => Text(
                            v >= 1 ? '€${v.toInt()}' : '',
                            style: typo.labelSmall.copyWith(
                              color: colors.textSoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          reservedSize: 28,
                          interval: maxY / 4,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (_) => FlLine(color: colors.border.withValues(alpha: 0.3)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: spots.map((s) => BarChartGroupData(
                      x: s.x.toInt(),
                      barRods: [
                        BarChartRodData(
                          toY: s.y,
                          color: colors.accent,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                      showingTooltipIndicators: [],
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Center(
          child: Text(
            DriverStrings.thisWeek,
            style: typo.labelSmall.copyWith(color: colors.textSoft),
          ),
        ),
      ),
    );
  }
}

class _TodayRideTile extends StatelessWidget {
  final TodayRide ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _TodayRideTile({
    required this.ride,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    final fareStr = ride.fare != null ? '€${ride.fare!.toStringAsFixed(2)}' : '—';
    final timeStr = ride.completedAt != null
        ? DateFormat('HH:mm').format(ride.completedAt!)
        : '—';
    final route = ride.displayRoute;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_taxi_outlined, color: colors.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              '$route · $fareStr · $timeStr',
              style: typo.bodyMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableRidesContent extends ConsumerWidget {
  final RideFilter filter;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final void Function(RideFilter) onFilterChange;

  const _AvailableRidesContent({
    required this.filter,
    required this.colors,
    required this.typo,
    required this.onFilterChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowAsync = ref.watch(availableRidesNowProvider);
    final marketplaceAsync = ref.watch(availableMarketplaceRidesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FilterChip(
                label: DriverStrings.now,
                isSelected: filter == RideFilter.now,
                colors: colors,
                typo: typo,
                onTap: () => onFilterChange(RideFilter.now),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: DriverStrings.scheduled,
                isSelected: filter == RideFilter.scheduled,
                colors: colors,
                typo: typo,
                onTap: () => onFilterChange(RideFilter.scheduled),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: DriverStrings.marketplace,
                isSelected: filter == RideFilter.marketplace,
                colors: colors,
                typo: typo,
                onTap: () => onFilterChange(RideFilter.marketplace),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filter == RideFilter.now
              ? nowAsync.when(
                  data: (rides) {
                    if (rides.isEmpty) {
                      return Center(
                        child: Text(
                          'No immediate rides',
                          style: typo.bodyMedium.copyWith(color: colors.textSoft),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: rides.length,
                      itemBuilder: (_, i) => _RideCard(
                        ride: rides[i],
                        colors: colors,
                        typo: typo,
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text(
                      DriverStrings.couldNotLoadRides,
                      style: typo.bodyMedium.copyWith(color: colors.textSoft),
                    ),
                  ),
                )
              : filter == RideFilter.scheduled
                  ? _ScheduledWorkTab(colors: colors, typo: typo)
                  : marketplaceAsync.when(
                      data: (rides) {
                        if (rides.isEmpty) {
                          return Center(
                            child: Text(
                              'No marketplace rides',
                              style: typo.bodyMedium.copyWith(
                                  color: colors.textSoft),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: rides.length,
                          itemBuilder: (_, i) => _RideCard(
                            ride: rides[i],
                            colors: colors,
                            typo: typo,
                          ),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => Center(
                        child: Text(
                          DriverStrings.couldNotLoadRides,
                          style: typo.bodyMedium
                              .copyWith(color: colors.textSoft),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentL : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
          ),
        ),
        child: Text(
          label,
          style: typo.bodySmall.copyWith(
            color: isSelected ? colors.accent : colors.text,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final ScheduledRide ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _RideCard({
    required this.ride,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    final fare = ride.estimatedFare != null
        ? '€${ride.estimatedFare!.toStringAsFixed(2)}'
        : '—';
    final time = ride.scheduledPickupAt != null
        ? DateFormat('HH:mm').format(ride.scheduledPickupAt!)
        : '—';
    final dist = ride.distanceKm != null
        ? '${ride.distanceKm!.toStringAsFixed(1)} km'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$fare · $time',
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (dist.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.directions_car, size: 16, color: colors.textSoft),
                const SizedBox(width: 4),
                Text(
                  dist,
                  style: typo.bodySmall.copyWith(color: colors.textSoft),
                ),
              ],
            ),
          ],
          if (ride.pickupAddress != null) ...[
            const SizedBox(height: 8),
            Text(
              ride.pickupAddress!,
              style: typo.bodySmall.copyWith(color: colors.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduledWorkTab extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _ScheduledWorkTab({
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedAsync = ref.watch(scheduledRidesByTabProvider('confirmed'));
    final requestsAsync = ref.watch(scheduledRidesProvider);

    return confirmedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          DriverStrings.couldNotLoadRides,
          style: typo.bodyMedium.copyWith(color: colors.textSoft),
        ),
      ),
      data: (confirmed) => requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            DriverStrings.couldNotLoadRides,
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
        ),
        data: (requests) {
          if (confirmed.isEmpty && requests.isEmpty) {
            return Center(
              child: Text(
                'No scheduled rides',
                style: typo.bodyMedium.copyWith(color: colors.textSoft),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (confirmed.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    DriverStrings.myAssignedScheduled,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...confirmed.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AssignedScheduledWorkCard(
                      ride: r,
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                ),
                if (requests.isNotEmpty) const SizedBox(height: 20),
              ],
              if (requests.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    DriverStrings.openScheduledRequests,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...requests.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RideCard(
                      ride: r,
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AssignedScheduledWorkCard extends ConsumerWidget {
  final ScheduledRide ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _AssignedScheduledWorkCard({
    required this.ride,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fare = ride.estimatedFare != null
        ? '€${ride.estimatedFare!.toStringAsFixed(2)}'
        : '—';
    final time = ride.scheduledPickupAt != null
        ? DateFormat('HH:mm').format(ride.scheduledPickupAt!)
        : '—';
    final dist = ride.distanceKm != null
        ? '${ride.distanceKm!.toStringAsFixed(1)} km'
        : '';

    return GestureDetector(
      onTap: () => context.push('/driver/ride/new/${ride.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$fare · $time',
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (dist.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dist,
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
            ],
            if (ride.pickupAddress != null) ...[
              const SizedBox(height: 8),
              Text(
                ride.pickupAddress!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typo.bodySmall.copyWith(color: colors.text),
              ),
            ],
            const SizedBox(height: 12),
            ScheduledPrerideActions(
              ride: ride,
              colors: colors,
              typo: typo,
              onInvalidate: () {
                ref.invalidate(scheduledRidesByTabProvider('confirmed'));
                ref.invalidate(scheduledRidesProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
