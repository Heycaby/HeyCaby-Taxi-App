import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_ride_card.dart';
import '../ui/driver_skeleton.dart';
import '../utils/driver_ride_ledger_display.dart';
import '../widgets/driver_ledger_flow_common.dart';

enum TodayFilter { all, completed, upcoming, cancelled }

class TodayRidesScreen extends ConsumerStatefulWidget {
  const TodayRidesScreen({super.key, this.initialFilter});

  final TodayFilter? initialFilter;

  @override
  ConsumerState<TodayRidesScreen> createState() => _TodayRidesScreenState();
}

class _TodayRidesScreenState extends ConsumerState<TodayRidesScreen> {
  late TodayFilter _filter = widget.initialFilter ?? TodayFilter.all;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver/work');
  }

  List<MyRideSummary> _applyFilter(List<MyRideSummary> rides) {
    switch (_filter) {
      case TodayFilter.completed:
        return rides
            .where((r) => driverCompletedRideStatuses.contains(r.status))
            .toList();
      case TodayFilter.cancelled:
        return rides
            .where((r) => driverCancelledRideStatuses.contains(r.status))
            .toList();
      case TodayFilter.upcoming:
        return rides
            .where((r) => driverUpcomingRideStatuses.contains(r.status))
            .toList();
      case TodayFilter.all:
        return rides;
    }
  }

  DriverLedgerHistoryItem _mapItem(MyRideSummary ride) {
    final when = ride.completedAt ?? ride.scheduledPickupAt ?? ride.createdAt;
    final date = when == null
        ? '—'
        : DateFormat('HH:mm').format(when.toLocal());
    final fare = ride.fare == null
        ? '—'
        : HeyCabyRideFare.formatEuroLabel(ride.fare) ?? '—';
    final from = (ride.pickupAddress ?? '—').trim();
    final to = (ride.destinationAddress ?? '—').trim();

    return DriverLedgerHistoryItem(
      dateLabel: date,
      pickupLabel: from,
      dropoffLabel: to,
      fareLabel: fare,
      statusLabel: driverRideStatusLabel(ride),
      statusTone: driverRideStatusTone(ride),
    );
  }

  String? _emptyMessage() {
    switch (_filter) {
      case TodayFilter.completed:
        return DriverStrings.noCompletedRides;
      case TodayFilter.cancelled:
        return DriverStrings.noCancelledRides;
      case TodayFilter.upcoming:
        return DriverStrings.noUpcomingRides;
      case TodayFilter.all:
        return DriverStrings.geenRittenVandaag;
    }
  }

  IconData _emptyIcon() {
    switch (_filter) {
      case TodayFilter.completed:
        return Icons.check_circle_outline_rounded;
      case TodayFilter.cancelled:
        return Icons.cancel_outlined;
      case TodayFilter.upcoming:
        return Icons.upcoming_rounded;
      case TodayFilter.all:
        return Icons.local_taxi_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final ridesAsync = ref.watch(todayMyRidesProvider);

    return ridesAsync.when(
      data: (rides) {
        final filtered = _applyFilter(rides);

        return DriverLedgerFlowScaffold(
          title: DriverStrings.todaysRides,
          colors: colors,
          typography: typography,
          onBack: () => _handleBack(context),
          body: Column(
            children: [
              _FilterBar(
                filter: _filter,
                colors: colors,
                typography: typography,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? DriverEmptyState(
                        icon: _emptyIcon(),
                        title: _emptyMessage()!,
                        colors: colors,
                        typography: typography,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          DriverSpacing.screenEdge,
                          DriverSpacing.sm,
                          DriverSpacing.screenEdge,
                          DriverSpacing.lg,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: DriverSpacing.md),
                        itemBuilder: (context, index) {
                          final ride = filtered[index];
                          final item = _mapItem(ride);
                          final category = driverRideCategoryLabel(ride);
                          return DriverRideCard(
                            colors: colors,
                            typography: typography,
                            pickupLabel: item.pickupLabel,
                            dropoffLabel: item.dropoffLabel,
                            fareLabel: item.fareLabel,
                            metaLabel: item.dateLabel,
                            statusLabel: item.statusLabel,
                            statusTone: item.statusTone,
                            categoryLabel: category,
                            categoryTone: driverRideCategoryTone(ride),
                            detailLabel: driverRideTaxiTerugDetail(ride),
                            onTap: () => context
                                .push('/driver/my-rides/${ride.id}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => DriverLedgerFlowScaffold(
        title: DriverStrings.todaysRides,
        colors: colors,
        typography: typography,
        onBack: () => _handleBack(context),
        body: Column(
          children: [
            _FilterBar(
              filter: _filter,
              colors: colors,
              typography: typography,
              onChanged: (_) {},
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(DriverSpacing.screenEdge),
                children: [
                  DriverSkeleton(colors: colors, height: 96),
                  const SizedBox(height: DriverSpacing.md),
                  DriverSkeleton(colors: colors, height: 96),
                ],
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => DriverLedgerFlowScaffold(
        title: DriverStrings.todaysRides,
        colors: colors,
        typography: typography,
        onBack: () => _handleBack(context),
        body: Column(
          children: [
            _FilterBar(
              filter: _filter,
              colors: colors,
              typography: typography,
              onChanged: (_) {},
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(DriverSpacing.xxl),
                  child: Text(
                    DriverStrings.myRidesLoadFailed,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.colors,
    required this.typography,
    required this.onChanged,
  });

  final TodayFilter filter;
  final DriverColors colors;
  final DriverTypography typography;
  final ValueChanged<TodayFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
        DriverSpacing.screenEdge,
        DriverSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterPill(
              label: DriverStrings.ridesFilterAll,
              icon: Icons.list_rounded,
              selected: filter == TodayFilter.all,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(TodayFilter.all),
            ),
            const SizedBox(width: DriverSpacing.sm),
            _FilterPill(
              label: DriverStrings.ridesFilterCompleted,
              icon: Icons.check_circle_outline_rounded,
              selected: filter == TodayFilter.completed,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(TodayFilter.completed),
            ),
            const SizedBox(width: DriverSpacing.sm),
            _FilterPill(
              label: DriverStrings.ridesFilterUpcoming,
              icon: Icons.upcoming_rounded,
              selected: filter == TodayFilter.upcoming,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(TodayFilter.upcoming),
            ),
            const SizedBox(width: DriverSpacing.sm),
            _FilterPill(
              label: DriverStrings.ridesFilterCancelled,
              icon: Icons.cancel_outlined,
              selected: filter == TodayFilter.cancelled,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(TodayFilter.cancelled),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? colors.primaryLight : colors.backgroundAlt;
    final fg = selected ? colors.primary : colors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(DriverRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: DriverSpacing.xs),
              Text(
                label,
                style: typography.labelMedium.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
