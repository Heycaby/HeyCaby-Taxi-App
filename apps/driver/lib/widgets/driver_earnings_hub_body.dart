import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_payment_ledger_item.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
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

/// **Earnings Hub** — today's number is the hero; breakdown at a glance.
class DriverEarningsHubBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DriverMoneyFlowScaffold(
      title: DriverStrings.financeHubTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      actions: [
        IconButton(
          icon: Icon(Icons.file_download_outlined, color: colors.primary),
          onPressed: exporting ? null : onExport,
        ),
      ],
      body: Column(
        children: [
          _FilterBar(
            colors: colors,
            typography: typography,
            selectedFilter: selectedFilter,
            onFilterSelected: onFilterSelected,
          ),
          Expanded(
            child: metricsLoading
                ? _LoadingSkeleton(colors: colors)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DriverSpacing.screenEdge,
                      DriverSpacing.md,
                      DriverSpacing.screenEdge,
                      DriverSpacing.xxl,
                    ),
                    children: [
                      _EarningsHero(
                        colors: colors,
                        typography: typography,
                        netEarnings: metrics.netEarnings,
                        rangeLabel: rangeLabel,
                      ).driverFadeSlideIn(staggerIndex: 0),
                      const SizedBox(height: DriverSpacing.lg),
                      _MetricsGrid(
                        colors: colors,
                        typography: typography,
                        metrics: metrics,
                      ),
                      const SizedBox(height: DriverSpacing.xl),
                      _BreakdownCard(
                        colors: colors,
                        typography: typography,
                        metrics: metrics,
                        onViewAllRides: onViewAllRides,
                      ).driverFadeSlideIn(staggerIndex: 2),
                      const SizedBox(height: DriverSpacing.xl),
                      _LedgerSection(
                        colors: colors,
                        typography: typography,
                        items: ledgerItems,
                        loading: ledgerLoading,
                      ).driverFadeSlideIn(staggerIndex: 3),
                      const SizedBox(height: DriverSpacing.xl),
                      _AccountantCard(
                        colors: colors,
                        typography: typography,
                        accountantEmail: accountantEmail,
                        onEdit: onEditAccountantEmail,
                      ).driverFadeSlideIn(staggerIndex: 4),
                      if (metricsError) ...[
                        const SizedBox(height: DriverSpacing.md),
                        Text(
                          DriverStrings.financeDataUnavailable,
                          style: typography.bodySmall.copyWith(
                            color: colors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
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
              letterSpacing: -0.8,
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
              Icon(Icons.person_outline_rounded, color: colors.primary, size: 20),
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
        TextButton(onPressed: onCancel, child: Text(DriverStrings.financeAccountantDialogCancel)),
        FilledButton(onPressed: onSave, child: Text(DriverStrings.financeAccountantDialogSave)),
      ],
    );
  }
}
