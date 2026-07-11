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
import '../ui/driver_status_badge.dart';
import '../widgets/driver_ledger_flow_common.dart';

enum _RideFilter { all, completed, cancelled, upcoming }

const _completedStatuses = {'completed'};
const _cancelledStatuses = {'cancelled'};
const _upcomingStatuses = {
  'accepted',
  'assigned',
  'driver_en_route',
  'driver_arrived',
  'in_progress',
  'pending',
  'dispatched',
};

class DriverMyRidesScreen extends ConsumerStatefulWidget {
  const DriverMyRidesScreen({super.key});

  @override
  ConsumerState<DriverMyRidesScreen> createState() =>
      _DriverMyRidesScreenState();
}

class _DriverMyRidesScreenState extends ConsumerState<DriverMyRidesScreen> {
  _RideFilter _filter = _RideFilter.all;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  List<MyRideSummary> _applyFilter(List<MyRideSummary> rides) {
    switch (_filter) {
      case _RideFilter.completed:
        return rides
            .where((r) => _completedStatuses.contains(r.status))
            .toList();
      case _RideFilter.cancelled:
        return rides
            .where((r) => _cancelledStatuses.contains(r.status))
            .toList();
      case _RideFilter.upcoming:
        return rides
            .where((r) => _upcomingStatuses.contains(r.status))
            .toList();
      case _RideFilter.all:
        return rides;
    }
  }

  DriverStatusTone _statusTone(MyRideSummary ride) {
    if (ride.manualEntry) return DriverStatusTone.warning;
    if (_completedStatuses.contains(ride.status))
      return DriverStatusTone.success;
    if (_cancelledStatuses.contains(ride.status)) return DriverStatusTone.error;
    return DriverStatusTone.neutral;
  }

  String _statusLabel(MyRideSummary ride) {
    if (ride.manualEntry) return DriverStrings.manualRideTag;
    if (_completedStatuses.contains(ride.status)) {
      return DriverStrings.rideCompleted;
    }
    if (_cancelledStatuses.contains(ride.status)) {
      return DriverStrings.rideCancelled;
    }
    return ride.status;
  }

  DriverLedgerHistoryItem _mapItem(MyRideSummary ride) {
    final date = ride.createdAt == null
        ? '—'
        : DateFormat('dd MMM yyyy, HH:mm').format(ride.createdAt!.toLocal());
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
      statusLabel: _statusLabel(ride),
      statusTone: _statusTone(ride),
    );
  }

  String? _emptyMessage() {
    switch (_filter) {
      case _RideFilter.completed:
        return DriverStrings.noCompletedRides;
      case _RideFilter.cancelled:
        return DriverStrings.noCancelledRides;
      case _RideFilter.upcoming:
        return DriverStrings.noUpcomingRides;
      case _RideFilter.all:
        return DriverStrings.noRidesYet;
    }
  }

  IconData _emptyIcon() {
    switch (_filter) {
      case _RideFilter.completed:
        return Icons.check_circle_outline_rounded;
      case _RideFilter.cancelled:
        return Icons.cancel_outlined;
      case _RideFilter.upcoming:
        return Icons.upcoming_rounded;
      case _RideFilter.all:
        return Icons.history_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final ridesAsync = ref.watch(myRidesProvider);

    return ridesAsync.when(
      data: (rides) {
        final filtered = _applyFilter(rides);
        final items = filtered.map(_mapItem).toList();

        return DriverLedgerFlowScaffold(
          title: DriverStrings.myRides,
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
                child: items.isEmpty
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
                            onTap: () => context
                                .push('/driver/my-rides/${filtered[index].id}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => DriverLedgerFlowScaffold(
        title: DriverStrings.myRides,
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
        title: DriverStrings.myRides,
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

  final _RideFilter filter;
  final DriverColors colors;
  final DriverTypography typography;
  final ValueChanged<_RideFilter> onChanged;

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
              selected: filter == _RideFilter.all,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(_RideFilter.all),
            ),
            const SizedBox(width: DriverSpacing.sm),
            _FilterPill(
              label: DriverStrings.ridesFilterCompleted,
              icon: Icons.check_circle_outline_rounded,
              selected: filter == _RideFilter.completed,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(_RideFilter.completed),
            ),
            const SizedBox(width: DriverSpacing.sm),
            _FilterPill(
              label: DriverStrings.ridesFilterCancelled,
              icon: Icons.cancel_outlined,
              selected: filter == _RideFilter.cancelled,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(_RideFilter.cancelled),
            ),
            const SizedBox(width: DriverSpacing.sm),
            _FilterPill(
              label: DriverStrings.ridesFilterUpcoming,
              icon: Icons.upcoming_rounded,
              selected: filter == _RideFilter.upcoming,
              colors: colors,
              typography: typography,
              onTap: () => onChanged(_RideFilter.upcoming),
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
