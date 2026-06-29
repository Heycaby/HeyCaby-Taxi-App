import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_statistic_card.dart';

/// Static earnings snapshot for shift-command golden previews.
class DriverShiftCommandEarningsSnapshot {
  const DriverShiftCommandEarningsSnapshot({
    required this.todayAmount,
    required this.weekRides,
    required this.weekAmount,
    required this.avgPerRide,
    required this.todayRideRows,
  });

  final String todayAmount;
  final int weekRides;
  final String weekAmount;
  final String avgPerRide;
  final List<String> todayRideRows;
}

/// Earnings tab preview panel (no providers).
class DriverShiftCommandEarningsPreview extends StatelessWidget {
  const DriverShiftCommandEarningsPreview({
    super.key,
    required this.colors,
    required this.typography,
    required this.snapshot,
    required this.todayRidesTitle,
    required this.avgPerRideLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverShiftCommandEarningsSnapshot snapshot;
  final String todayRidesTitle;
  final String avgPerRideLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.md,
        DriverSpacing.screenEdge,
        DriverSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DriverCard(
            colors: colors,
            padding: const EdgeInsets.all(DriverSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: DriverRadius.smAll,
                  ),
                  child: Icon(Icons.payments_outlined, color: colors.primary),
                ),
                const SizedBox(width: DriverSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DriverStrings.today,
                        style: typography.labelLarge.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        snapshot.todayAmount,
                        style: typography.displaySmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DriverStatisticCard(
                  label: DriverStrings.ridesThisWeek,
                  value: '${snapshot.weekRides}',
                  colors: colors,
                  typography: typography,
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: DriverStatisticCard(
                  label: DriverStrings.thisWeek,
                  value: snapshot.weekAmount,
                  colors: colors,
                  typography: typography,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          DriverCard(
            colors: colors,
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.md,
              vertical: DriverSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    color: colors.success, size: 18),
                const SizedBox(width: DriverSpacing.sm),
                Text(
                  '$avgPerRideLabel: ${snapshot.avgPerRide}',
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DriverSpacing.xl),
          Text(
            todayRidesTitle,
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          ...snapshot.todayRideRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
              child: DriverCard(
                colors: colors,
                padding: const EdgeInsets.all(DriverSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.local_taxi_outlined,
                        color: colors.primary, size: 18),
                    const SizedBox(width: DriverSpacing.sm),
                    Expanded(
                      child: Text(
                        row,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

/// Shell for shift-command golden — earnings tab only.
class DriverShiftCommandShellPreview extends StatelessWidget {
  const DriverShiftCommandShellPreview({
    super.key,
    required this.colors,
    required this.typography,
    required this.earningsTab,
    required this.availableRidesTab,
    required this.earningsSelected,
    required this.content,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String earningsTab;
  final String availableRidesTab;
  final bool earningsSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: Icon(Icons.arrow_back_rounded, color: colors.text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                      label: earningsTab,
                      selected: earningsSelected,
                      colors: colors,
                      typography: typography,
                    ),
                  ),
                  const SizedBox(width: DriverSpacing.sm),
                  Expanded(
                    child: _TabPill(
                      label: availableRidesTab,
                      selected: !earningsSelected,
                      colors: colors,
                      typography: typography,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typography,
  });

  final String label;
  final bool selected;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DriverSpacing.md),
      decoration: BoxDecoration(
        color: selected ? colors.surface : colors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? colors.border : Colors.transparent,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: typography.bodyMedium.copyWith(
          color: selected ? colors.text : colors.textMuted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
