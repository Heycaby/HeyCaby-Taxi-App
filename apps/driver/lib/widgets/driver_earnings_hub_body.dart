import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_payment_ledger_item.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_chip.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_statistic_card.dart';
import '../ui/driver_text_field.dart';
import 'driver_money_flow_common.dart';

/// Date range filter for the Earnings Hub.
enum DriverFinanceDateFilter {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisYear,
  custom,
}

extension DriverFinanceDateFilterLabels on DriverFinanceDateFilter {
  String get label {
    switch (this) {
      case DriverFinanceDateFilter.today:
        return DriverStrings.financeRangeToday;
      case DriverFinanceDateFilter.thisWeek:
        return DriverStrings.financeRangeThisWeek;
      case DriverFinanceDateFilter.thisMonth:
        return DriverStrings.financeRangeThisMonth;
      case DriverFinanceDateFilter.thisQuarter:
        return DriverStrings.financeRangeThisQuarter;
      case DriverFinanceDateFilter.thisYear:
        return DriverStrings.financeRangeThisYear;
      case DriverFinanceDateFilter.custom:
        return DriverStrings.financeRangeCustom;
    }
  }
}

/// Tab index for the Earnings Hub.
enum DriverFinanceTab { overview, savings }

/// **Earnings Hub** — today's number is the hero; breakdown at a glance.
class DriverEarningsHubBody extends StatefulWidget {
  const DriverEarningsHubBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.selectedFilter,
    required this.rangeLabel,
    required this.metrics,
    required this.metricsLoading,
    required this.metricsError,
    required this.ledgerItems,
    required this.ledgerLoading,
    required this.accountantEmail,
    required this.exporting,
    required this.onBack,
    required this.onFilterSelected,
    required this.onExport,
    required this.onViewAllRides,
    required this.onEditAccountantEmail,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceDateFilter selectedFilter;
  final String rangeLabel;
  final DriverFinanceMetrics metrics;
  final bool metricsLoading;
  final bool metricsError;
  final List<DriverPaymentLedgerItem> ledgerItems;
  final bool ledgerLoading;
  final String? accountantEmail;
  final bool exporting;
  final VoidCallback onBack;
  final ValueChanged<DriverFinanceDateFilter> onFilterSelected;
  final VoidCallback onExport;
  final VoidCallback onViewAllRides;
  final VoidCallback onEditAccountantEmail;

  @override
  State<DriverEarningsHubBody> createState() => _DriverEarningsHubBodyState();
}

class _DriverEarningsHubBodyState extends State<DriverEarningsHubBody> {
  DriverFinanceTab _tab = DriverFinanceTab.overview;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final t = widget.typography;
    return DriverMoneyFlowScaffold(
      title: DriverStrings.financeHubTitle,
      colors: c,
      typography: t,
      onBack: widget.onBack,
      actions: [
        IconButton(
          icon: Icon(Icons.file_download_outlined, color: c.primary),
          onPressed: widget.exporting ? null : widget.onExport,
        ),
      ],
      body: Column(
        children: [
          _FilterBar(
            colors: c,
            typography: t,
            selectedFilter: widget.selectedFilter,
            onFilterSelected: widget.onFilterSelected,
          ),
          _TabBar(
            colors: c,
            typography: t,
            selectedTab: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
          Expanded(
            child: widget.metricsLoading
                ? _LoadingSkeleton(colors: c)
                : _tab == DriverFinanceTab.overview
                    ? _buildOverview(c, t)
                    : _buildSavings(c, t),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(DriverColors c, DriverTypography t) {
    final m = widget.metrics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.md,
        DriverSpacing.screenEdge,
        DriverSpacing.xxl,
      ),
      children: [
        _EarningsHero(
          colors: c,
          typography: t,
          netEarnings: m.netEarnings,
          rangeLabel: widget.rangeLabel,
        ).driverFadeSlideIn(staggerIndex: 0),
        const SizedBox(height: DriverSpacing.lg),
        _MetricsGrid(
          colors: c,
          typography: t,
          metrics: m,
        ),
        const SizedBox(height: DriverSpacing.xl),
        _IncomeChartCard(
          colors: c,
          typography: t,
          metrics: m,
        ).driverFadeSlideIn(staggerIndex: 2),
        const SizedBox(height: DriverSpacing.xl),
        _BreakdownCard(
          colors: c,
          typography: t,
          metrics: m,
          onViewAllRides: widget.onViewAllRides,
        ).driverFadeSlideIn(staggerIndex: 3),
        const SizedBox(height: DriverSpacing.xl),
        _RidesListCard(
          colors: c,
          typography: t,
          metrics: m,
        ).driverFadeSlideIn(staggerIndex: 4),
        const SizedBox(height: DriverSpacing.xl),
        _LedgerSection(
          colors: c,
          typography: t,
          items: widget.ledgerItems,
          loading: widget.ledgerLoading,
        ).driverFadeSlideIn(staggerIndex: 5),
        const SizedBox(height: DriverSpacing.xl),
        _AccountantCard(
          colors: c,
          typography: t,
          accountantEmail: widget.accountantEmail,
          onEdit: widget.onEditAccountantEmail,
        ).driverFadeSlideIn(staggerIndex: 6),
        if (widget.metricsError) ...[
          const SizedBox(height: DriverSpacing.md),
          Text(
            DriverStrings.financeDataUnavailable,
            style: t.bodySmall.copyWith(color: c.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildSavings(DriverColors c, DriverTypography t) {
    final m = widget.metrics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.md,
        DriverSpacing.screenEdge,
        DriverSpacing.xxl,
      ),
      children: [
        _SavingsHero(
          colors: c,
          typography: t,
          metrics: m,
          rangeLabel: widget.rangeLabel,
        ).driverFadeSlideIn(staggerIndex: 0),
        const SizedBox(height: DriverSpacing.lg),
        _SavingsDescriptionCard(
          colors: c,
          typography: t,
        ).driverFadeSlideIn(staggerIndex: 1),
        const SizedBox(height: DriverSpacing.xl),
        _SavingsChartCard(
          colors: c,
          typography: t,
          metrics: m,
        ).driverFadeSlideIn(staggerIndex: 2),
        const SizedBox(height: DriverSpacing.xl),
        _SavingsBreakdownCard(
          colors: c,
          typography: t,
          metrics: m,
        ).driverFadeSlideIn(staggerIndex: 3),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.colors,
    required this.typography,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceDateFilter selectedFilter;
  final ValueChanged<DriverFinanceDateFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.md,
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
      ),
      child: Row(
        children: [
          for (final filter in DriverFinanceDateFilter.values) ...[
            DriverChip(
              label: filter.label,
              colors: colors,
              typography: typography,
              selected: selectedFilter == filter,
              onTap: () => onFilterSelected(filter),
            ),
            const SizedBox(width: DriverSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({
    required this.colors,
    required this.typography,
    required this.netEarnings,
    required this.rangeLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final double netEarnings;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rangeLabel,
            style: typography.labelMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            DriverStrings.financeMetricsNetEarnings,
            style: typography.labelMedium.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          DriverAnimatedEarnings(
            value: _eur(netEarnings),
            style: typography.displaySmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.colors,
    required this.typography,
    required this.metrics,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: DriverSpacing.md,
      crossAxisSpacing: DriverSpacing.md,
      childAspectRatio: 1.28,
      children: [
        DriverStatisticCard(
          colors: colors,
          typography: typography,
          label: DriverStrings.financeMetricsTotalEarnings,
          value: _eur(metrics.grossEarnings),
          icon: Icons.euro_rounded,
        ).driverFadeSlideIn(staggerIndex: 1),
        DriverStatisticCard(
          colors: colors,
          typography: typography,
          label: DriverStrings.financeMetricsTotalRides,
          value: '${metrics.totalRides}',
          icon: Icons.directions_car_rounded,
        ).driverFadeSlideIn(staggerIndex: 1),
        DriverStatisticCard(
          colors: colors,
          typography: typography,
          label: DriverStrings.financeMetricsKm,
          value: _km(metrics.totalKilometers),
          icon: Icons.route_rounded,
        ).driverFadeSlideIn(staggerIndex: 1),
        DriverStatisticCard(
          colors: colors,
          typography: typography,
          label: DriverStrings.financeMetricsTips,
          value: _eur(metrics.tips ?? 0),
          icon: Icons.tips_and_updates_outlined,
        ).driverFadeSlideIn(staggerIndex: 1),
        DriverStatisticCard(
          colors: colors,
          typography: typography,
          label: DriverStrings.financeMetricsAverageFare,
          value: _eur(metrics.averageFare),
          icon: Icons.trending_up_rounded,
        ).driverFadeSlideIn(staggerIndex: 2),
        DriverStatisticCard(
          colors: colors,
          typography: typography,
          label: DriverStrings.financeMetricsHoursOnline,
          value:
              '${metrics.hoursOnline.toStringAsFixed(1).replaceAll('.', ',')} u',
          subtitle:
              '${metrics.totalShifts} ${DriverStrings.financeMetricsTotalShifts}',
          icon: Icons.schedule_rounded,
        ).driverFadeSlideIn(staggerIndex: 2),
      ],
    );
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  String _km(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} km';
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.colors,
    required this.typography,
    required this.metrics,
    required this.onViewAllRides,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;
  final VoidCallback onViewAllRides;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.financeBreakdownTitle,
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeBreakdownCompleted,
            value: '${metrics.completedRides}',
            colors: colors,
            typography: typography,
          ),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeBreakdownCancelled,
            value: '${metrics.cancelledRides}',
            colors: colors,
            typography: typography,
          ),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeBreakdownCancelFees,
            value: _eur(metrics.cancellationFees),
            colors: colors,
            typography: typography,
          ),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeMetricsPlatformFees,
            value: _eur(metrics.platformFees ?? 0),
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: DriverSpacing.md),
          DriverButton(
            label: DriverStrings.financeViewAllRides,
            icon: Icons.list_rounded,
            onPressed: onViewAllRides,
            variant: DriverButtonVariant.secondary,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({
    required this.colors,
    required this.typography,
    required this.items,
    required this.loading,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverPaymentLedgerItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.financePaymentReconciliationTitle,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          if (loading)
            Center(child: DriverSkeleton(colors: colors, height: 48))
          else if (items.isEmpty)
            Text(
              DriverStrings.financeNoPaymentRecords,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            )
          else
            for (final item in items.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: DriverSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: typography.bodySmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: typography.labelSmall.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.amountLabel != null)
                      Text(
                        item.amountLabel!,
                        style: typography.bodySmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AccountantCard extends StatelessWidget {
  const _AccountantCard({
    required this.colors,
    required this.typography,
    required this.accountantEmail,
    required this.onEdit,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String? accountantEmail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final empty = accountantEmail == null || accountantEmail!.isEmpty;

    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  color: colors.primary, size: 20),
              const SizedBox(width: DriverSpacing.sm),
              Text(
                DriverStrings.financeAccountantTitle,
                style: typography.labelMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          Text(
            empty
                ? DriverStrings.financeAccountantEmptyHint
                : '${DriverStrings.financeAccountantCurrentPrefix} $accountantEmail',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverButton(
            label: empty
                ? DriverStrings.financeAccountantAdd
                : DriverStrings.financeAccountantEdit,
            icon: empty ? Icons.add_rounded : Icons.edit_outlined,
            onPressed: onEdit,
            variant: DriverButtonVariant.outline,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.colors,
    required this.typography,
    required this.selectedTab,
    required this.onSelect,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceTab selectedTab;
  final ValueChanged<DriverFinanceTab> onSelect;

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
            child: _TabPill(
              label: DriverStrings.financeTabOverview,
              icon: Icons.bar_chart_rounded,
              colors: colors,
              typography: typography,
              selected: selectedTab == DriverFinanceTab.overview,
              onTap: () => onSelect(DriverFinanceTab.overview),
            ),
          ),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: _TabPill(
              label: DriverStrings.financeTabSavings,
              icon: Icons.savings_outlined,
              colors: colors,
              typography: typography,
              selected: selectedTab == DriverFinanceTab.savings,
              onTap: () => onSelect(DriverFinanceTab.savings),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.colors,
    required this.typography,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final DriverColors colors;
  final DriverTypography typography;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.primary : colors.card,
      borderRadius: DriverRadius.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.lg,
            vertical: DriverSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? colors.onPrimary : colors.textSecondary,
              ),
              const SizedBox(width: DriverSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: typography.labelMedium.copyWith(
                    color: selected ? colors.onPrimary : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
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

class _IncomeChartCard extends StatelessWidget {
  const _IncomeChartCard({
    required this.colors,
    required this.typography,
    required this.metrics,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final fareTotal = metrics.grossEarnings;
    final tipTotal = metrics.tips ?? 0;
    final cancelTotal = metrics.cancellationFees;
    final total = fareTotal + tipTotal + cancelTotal;

    if (total <= 0) {
      return DriverCard(
        colors: colors,
        child: Column(
          children: [
            Text(
              DriverStrings.financeChartIncomeBreakdown,
              style: typography.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DriverSpacing.lg),
            Text(
              DriverStrings.financeNoPaymentRecords,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      );
    }

    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.financeChartIncomeBreakdown,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.xl),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        if (fareTotal > 0)
                          PieChartSectionData(
                            value: fareTotal,
                            color: colors.primary,
                            radius: 32,
                            titleStyle: typography.labelSmall.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            title: '${(fareTotal / total * 100).round()}%',
                          ),
                        if (tipTotal > 0)
                          PieChartSectionData(
                            value: tipTotal,
                            color: colors.warning,
                            radius: 28,
                            titleStyle: typography.labelSmall.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            title: '${(tipTotal / total * 100).round()}%',
                          ),
                        if (cancelTotal > 0)
                          PieChartSectionData(
                            value: cancelTotal,
                            color: colors.error,
                            radius: 24,
                            titleStyle: typography.labelSmall.copyWith(
                              color: colors.onError,
                              fontWeight: FontWeight.w700,
                            ),
                            title: '${(cancelTotal / total * 100).round()}%',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DriverSpacing.lg),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ChartLegend(
                        color: colors.primary,
                        label: DriverStrings.financeReportGross,
                        value: _eur(fareTotal),
                        colors: colors,
                        typography: typography,
                      ),
                      const SizedBox(height: DriverSpacing.sm),
                      _ChartLegend(
                        color: colors.warning,
                        label: DriverStrings.financeReportTips,
                        value: _eur(tipTotal),
                        colors: colors,
                        typography: typography,
                      ),
                      if (cancelTotal > 0) ...[
                        const SizedBox(height: DriverSpacing.sm),
                        _ChartLegend(
                          color: colors.error,
                          label: DriverStrings.financeReportCancellationFees,
                          value: _eur(cancelTotal),
                          colors: colors,
                          typography: typography,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.color,
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });

  final Color color;
  final String label;
  final String value;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: DriverSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: typography.labelSmall.copyWith(color: colors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: typography.labelSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RidesListCard extends StatelessWidget {
  const _RidesListCard({
    required this.colors,
    required this.typography,
    required this.metrics,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final rides = metrics.rideBreakdown;
    if (rides.isEmpty) return const SizedBox.shrink();

    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.financeReportSectionSummary,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          for (final ride in rides.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: DriverSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.completedAt != null
                              ? _formatDate(ride.completedAt!)
                              : '—',
                          style: typography.bodySmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_km(ride.distanceKm)} · ${ride.paymentMethod ?? "—"}',
                          style: typography.labelSmall.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _eur(ride.fare + ride.tip),
                    style: typography.bodySmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _km(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} km';
  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Savings tab widgets
// ---------------------------------------------------------------------------

const _heycabyWeeklyFeeEur = 50.0;
const _otherPlatformCommissionRate = 0.25;

class _SavingsHero extends StatelessWidget {
  const _SavingsHero({
    required this.colors,
    required this.typography,
    required this.metrics,
    required this.rangeLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final gross = metrics.grossEarnings;
    final estimatedCommission = gross * _otherPlatformCommissionRate;
    final savings = estimatedCommission -
        _heycabyWeeklyFeeEur * _weeksInRange(rangeLabel).toDouble();
    final displaySavings = savings > 0 ? savings : 0.0;

    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.financeSavingsTitle,
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            rangeLabel,
            style: typography.labelMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DriverSpacing.lg),
          Text(
            DriverStrings.financeSavingsYouSave,
            style: typography.labelMedium.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          DriverAnimatedEarnings(
            value: _eur(displaySavings),
            style: typography.displaySmall.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  int _weeksInRange(String label) {
    if (label.contains('week') || label.contains('Week')) return 1;
    if (label.contains('maand') ||
        label.contains('month') ||
        label.contains('Month')) return 4;
    if (label.contains('kwartaal') ||
        label.contains('quarter') ||
        label.contains('Quarter')) return 13;
    if (label.contains('jaar') ||
        label.contains('year') ||
        label.contains('Year')) return 52;
    if (label.contains('vandaag') ||
        label.contains('today') ||
        label.contains('Today')) return 1;
    return 4;
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _SavingsDescriptionCard extends StatelessWidget {
  const _SavingsDescriptionCard({
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
              const SizedBox(width: DriverSpacing.sm),
              Text(
                DriverStrings.financeSavingsSubtitle,
                style: typography.labelMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          Text(
            DriverStrings.financeSavingsDescription,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SavingsChartCard extends StatelessWidget {
  const _SavingsChartCard({
    required this.colors,
    required this.typography,
    required this.metrics,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final gross = metrics.grossEarnings;
    final estimatedCommission = gross * _otherPlatformCommissionRate;
    final weeks = _estimateWeeks(metrics.hoursOnline);
    final heycabyCost = _heycabyWeeklyFeeEur * weeks.toDouble();
    final maxVal = math.max(estimatedCommission, heycabyCost);

    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.financeSavingsChartTitle,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.xl),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupAmount, rod, rodAmount) {
                      return BarTooltipItem(
                        '€ ${rodAmount.toStringAsFixed(2)}',
                        typography.labelSmall.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = [
                          DriverStrings.financeSavingsHeyCabyCost,
                          DriverStrings.financeSavingsEstimatedCommission,
                        ];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length)
                          return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: DriverSpacing.xs),
                          child: Text(
                            labels[idx],
                            style: typography.labelSmall.copyWith(
                              color: colors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: heycabyCost,
                        color: colors.primary,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: estimatedCommission,
                        color: colors.error,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _estimateWeeks(double hoursOnline) {
    if (hoursOnline <= 0) return 4;
    final weeks = (hoursOnline / 40).ceil();
    return weeks.clamp(1, 52);
  }
}

class _SavingsBreakdownCard extends StatelessWidget {
  const _SavingsBreakdownCard({
    required this.colors,
    required this.typography,
    required this.metrics,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverFinanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final gross = metrics.grossEarnings;
    final estimatedCommission = gross * _otherPlatformCommissionRate;
    final weeks = _estimateWeeks(metrics.hoursOnline);
    final heycabyCost = _heycabyWeeklyFeeEur * weeks.toDouble();
    final savings = estimatedCommission - heycabyCost;
    final displaySavings = savings > 0 ? savings : 0.0;

    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DriverStrings.financeSavingsChartTitle,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeSavingsWeeklyFee,
            value: '€ ${_heycabyWeeklyFeeEur.toStringAsFixed(0)}',
            colors: colors,
            typography: typography,
          ),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeSavingsCommissionRate,
            value:
                '${(_otherPlatformCommissionRate * 100).toStringAsFixed(0)}%',
            colors: colors,
            typography: typography,
          ),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeSavingsEstimatedCommission,
            value: _eur(estimatedCommission),
            colors: colors,
            typography: typography,
            valueColor: colors.error,
          ),
          DriverMoneyKeyValueRow(
            label: DriverStrings.financeSavingsHeyCabyCost,
            value: _eur(heycabyCost),
            colors: colors,
            typography: typography,
            valueColor: colors.primary,
          ),
          const SizedBox(height: DriverSpacing.md),
          Container(
            padding: const EdgeInsets.all(DriverSpacing.lg),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: DriverRadius.smAll,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DriverStrings.financeSavingsTotalSavings,
                    style: typography.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _eur(displaySavings),
                  style: typography.titleMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _estimateWeeks(double hoursOnline) {
    if (hoursOnline <= 0) return 4;
    final weeks = (hoursOnline / 40).ceil();
    return weeks.clamp(1, 52);
  }

  String _eur(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.colors});

  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DriverSpacing.screenEdge),
      children: [
        DriverSkeleton(colors: colors, height: 120),
        const SizedBox(height: DriverSpacing.lg),
        DriverSkeleton(colors: colors, height: 200),
      ],
    );
  }
}

/// Accountant email dialog content — keeps TextField styling in the kit.
class DriverAccountantEmailDialog extends StatelessWidget {
  const DriverAccountantEmailDialog({
    super.key,
    required this.colors,
    required this.typography,
    required this.controller,
    required this.onCancel,
    required this.onSave,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: colors.card,
      title: Text(
        DriverStrings.financeAccountantDialogTitle,
        style: typography.titleMedium.copyWith(color: colors.text),
      ),
      content: DriverTextField(
        controller: controller,
        colors: colors,
        typography: typography,
        label: DriverStrings.financeAccountantDialogHint,
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(
            onPressed: onCancel,
            child: Text(DriverStrings.financeAccountantDialogCancel)),
        FilledButton(
            onPressed: onSave,
            child: Text(DriverStrings.financeAccountantDialogSave)),
      ],
    );
  }
}
