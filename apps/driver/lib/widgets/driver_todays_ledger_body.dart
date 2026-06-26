import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_ride_card.dart';
import '../ui/driver_skeleton.dart';
import 'driver_ledger_flow_common.dart';

/// Compact ride row for Today's Ledger.
class DriverTodaysLedgerRow {
  const DriverTodaysLedgerRow({
    required this.routeLabel,
    required this.fareLabel,
    required this.timeLabel,
  });

  final String routeLabel;
  final String fareLabel;
  final String timeLabel;
}

/// **Today's Ledger** — today's trips and totals at a glance.
class DriverTodaysLedgerBody extends StatelessWidget {
  const DriverTodaysLedgerBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.errorMessage,
    required this.rows,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? errorMessage;
  final List<DriverTodaysLedgerRow> rows;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverLedgerFlowScaffold(
      title: DriverStrings.todaysRides,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(child: DriverSkeleton(colors: colors, width: 200, height: 24))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xxl),
                    child: Text(
                      errorMessage!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : rows.isEmpty
                  ? DriverEmptyState(
                      icon: Icons.local_taxi_rounded,
                      title: DriverStrings.geenRittenVandaag,
                      colors: colors,
                      typography: typography,
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        DriverSpacing.screenEdge,
                        DriverSpacing.md,
                        DriverSpacing.screenEdge,
                        bottomPad + DriverSpacing.lg,
                      ),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: DriverSpacing.sm),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return DriverLedgerCompactRow(
                          routeLabel: row.routeLabel,
                          fareLabel: row.fareLabel,
                          timeLabel: row.timeLabel,
                          colors: colors,
                          typography: typography,
                        ).driverFadeSlideIn(staggerIndex: index);
                      },
                    ),
    );
  }
}

/// **Ride History** — past trips searchable and scannable.
class DriverRideHistoryBody extends StatelessWidget {
  const DriverRideHistoryBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.errorMessage,
    required this.items,
    required this.onBack,
    required this.onItemTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? errorMessage;
  final List<DriverLedgerHistoryItem> items;
  final VoidCallback onBack;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverLedgerFlowScaffold(
      title: DriverStrings.myRides,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? ListView(
              padding: const EdgeInsets.all(DriverSpacing.screenEdge),
              children: [
                DriverSkeleton(colors: colors, height: 96),
                const SizedBox(height: DriverSpacing.md),
                DriverSkeleton(colors: colors, height: 96),
              ],
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xxl),
                    child: Text(
                      errorMessage!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : items.isEmpty
                  ? DriverEmptyState(
                      icon: Icons.history_rounded,
                      title: DriverStrings.noRidesYet,
                      colors: colors,
                      typography: typography,
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        DriverSpacing.screenEdge,
                        DriverSpacing.md,
                        DriverSpacing.screenEdge,
                        bottomPad + DriverSpacing.lg,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: DriverSpacing.md),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return DriverRideCard(
                          colors: colors,
                          typography: typography,
                          pickupLabel: item.pickupLabel,
                          dropoffLabel: item.dropoffLabel,
                          fareLabel: item.fareLabel,
                          metaLabel: item.dateLabel,
                          statusLabel: item.statusLabel,
                          statusTone: item.statusTone,
                          onTap: () => onItemTap(index),
                        ).driverFadeSlideIn(staggerIndex: index);
                      },
                    ),
    );
  }
}
