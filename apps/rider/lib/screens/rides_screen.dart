import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../widgets/rides/rides_screen_header.dart';
import '../providers/near_term_ride_request_provider.dart';
import 'report_screen.dart';
import '../providers/ride_history_provider.dart';

class RidesScreen extends ConsumerStatefulWidget {
  const RidesScreen({super.key});

  @override
  ConsumerState<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends ConsumerState<RidesScreen> {
  int _selectedTab = 0;

  /// 0 = upcoming open requests, 1 = history from `rides` table.
  int _segment = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setFilter();
    });
  }

  void _setFilter() {
    final filter = _getFilter(_selectedTab);
    ref.read(rideHistoryProvider.notifier).setFilter(filter);
  }

  Future<void> _refreshHistory() async {
    await ref.read(rideHistoryProvider.notifier).refresh();
  }

  Future<void> _refreshUpcoming() async {
    ref.invalidate(ridesTabUpcomingRequestsProvider);
    await ref.read(ridesTabUpcomingRequestsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RidesScreenHeader(colors: colors, typo: typo, l10n: l10n),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
              child: _RidesSegmentBar(
                colors: colors,
                typo: typo,
                l10n: l10n,
                selected: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: IndexedStack(
                index: _segment,
                children: [
                  _UpcomingRidesTab(
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onRefresh: _refreshUpcoming,
                  ),
                  _HistoryRidesTab(
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    selectedTab: _selectedTab,
                    onFilterChanged: (v) {
                      setState(() {
                        _selectedTab = v;
                        _setFilter();
                      });
                    },
                    onRefresh: _refreshHistory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilter(int index) {
    switch (index) {
      case 0:
        return 'active';
      case 1:
        return 'bidding';
      case 2:
        return 'completed';
      case 3:
        return 'cancelled';
      default:
        return 'all';
    }
  }
}

class _RidesSegmentBar extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int selected;
  final ValueChanged<int> onChanged;

  const _RidesSegmentBar({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentCell(
              label: l10n.ridesTabUpcoming,
              selected: selected == 0,
              colors: colors,
              typo: typo,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentCell(
              label: l10n.ridesTabHistory,
              selected: selected == 1,
              colors: colors,
              typo: typo,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _SegmentCell({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? colors.accentL : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(color: colors.accent.withValues(alpha: 0.25))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                style: typo.labelLarge.copyWith(
                  color: selected ? colors.accent : colors.textMid,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingRidesTab extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final Future<void> Function() onRefresh;

  const _UpcomingRidesTab({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(ridesTabUpcomingRequestsProvider);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();

    return upcoming.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.accent)),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            color: colors.accent,
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 24),
              children: [
                _UpcomingEmpty(colors: colors, typo: typo, l10n: l10n),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: colors.accent,
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final snap = items[index];
              final isFutureScheduled = snap.scheduledPickupAt != null &&
                  snap.scheduledPickupAt!.isAfter(now);
              return _UpcomingRideRequestCard(
                snap: snap,
                colors: colors,
                typo: typo,
                l10n: l10n,
                locale: locale,
                isFutureScheduled: isFutureScheduled,
                onTap: () {
                  context.push(
                    '/upcoming-ride',
                    extra: snap,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _UpcomingEmpty extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _UpcomingEmpty({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsetsDirectional.all(28),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.event_available_rounded,
              size: 44, color: colors.accent),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.ridesUpcomingEmptyTitle,
          textAlign: TextAlign.center,
          style: typo.headingSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.ridesUpcomingEmptyBody,
          textAlign: TextAlign.center,
          style: typo.bodyMedium.copyWith(
            color: colors.textMid,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _UpcomingRideRequestCard extends StatelessWidget {
  final NearTermRideSnapshot snap;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String locale;
  final bool isFutureScheduled;
  final VoidCallback onTap;

  const _UpcomingRideRequestCard({
    required this.snap,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.locale,
    required this.isFutureScheduled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final when = snap.scheduledPickupAt;
    final whenText = (isFutureScheduled && when != null)
        ? DateFormat.yMMMd(locale).add_Hm().format(when)
        : null;

    final badgeLabel = isFutureScheduled
        ? l10n.ridesUpcomingScheduledBadge
        : l10n.ridesUpcomingMatchingBadge;
    final badgeColor = isFutureScheduled ? colors.accent : colors.warning;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFutureScheduled
                  ? colors.accent.withValues(alpha: 0.45)
                  : colors.border,
              width: isFutureScheduled ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeLabel,
                        style: typo.labelSmall.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: colors.textSoft),
                  ],
                ),
                const SizedBox(height: 12),
                if (whenText != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 18, color: colors.textMid),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          whenText,
                          style: typo.titleSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  snap.pickupAddress.isNotEmpty
                      ? snap.pickupAddress.split(',').first
                      : '—',
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  snap.destinationAddress.isNotEmpty
                      ? snap.destinationAddress.split(',').first
                      : '—',
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRidesTab extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int selectedTab;
  final ValueChanged<int> onFilterChanged;
  final Future<void> Function() onRefresh;

  const _HistoryRidesTab({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.selectedTab,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Text(
            l10n.ridesHistorySectionTitle,
            style: typo.titleSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        _FilterTabs(
          selected: selectedTab,
          colors: colors,
          typo: typo,
          l10n: l10n,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ref.watch(rideHistoryProvider).when(
                data: (rides) {
                  if (rides.isEmpty) {
                    return _EmptyState(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    color: colors.accent,
                    child: ListView.builder(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 24),
                      itemCount: rides.length,
                      itemBuilder: (context, index) => _RideCard(
                        ride: rides[index],
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                        onTap: () => context.push(
                          '/ride-detail',
                          extra: rides[index],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (_, __) => _EmptyState(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
              ),
        ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final int selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<int> onChanged;

  const _FilterTabs({
    required this.selected,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Tab(
              label: l10n.ridesFilterActive,
              isSelected: selected == 0,
              colors: colors,
              typo: typo,
              onTap: () => onChanged(0)),
          const SizedBox(width: 8),
          _Tab(
              label: l10n.ridesFilterBidding,
              isSelected: selected == 1,
              colors: colors,
              typo: typo,
              onTap: () => onChanged(1)),
          const SizedBox(width: 8),
          _Tab(
              label: l10n.ridesFilterCompleted,
              icon: Icons.check_circle_outline,
              isSelected: selected == 2,
              colors: colors,
              typo: typo,
              onTap: () => onChanged(2)),
          const SizedBox(width: 8),
          _Tab(
              label: l10n.ridesFilterCancelled,
              badge: '1',
              isSelected: selected == 3,
              colors: colors,
              typo: typo,
              onTap: () => onChanged(3)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? badge;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    this.icon,
    this.badge,
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
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: isSelected ? colors.bg : colors.textMid, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: typo.labelLarge.copyWith(
                color: isSelected ? colors.bg : colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.bg.withValues(alpha: 0.2)
                      : colors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: typo.labelSmall.copyWith(
                    color: isSelected ? colors.bg : colors.bg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _EmptyState({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(22),
            decoration: BoxDecoration(
              color: colors.accentL,
              shape: BoxShape.circle,
              border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noRidesInCategory,
            style: typo.headingMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tryDifferentFilter,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideHistoryItem ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _RideCard({
    required this.ride,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (ride.status) {
      case 'completed':
        return colors.success;
      case 'cancelled':
        return colors.error;
      case 'pending':
      case 'assigned':
      case 'arrived':
      case 'in_progress':
        return colors.accent;
      default:
        return colors.textMid;
    }
  }

  String _getStatusLabel() {
    switch (ride.status) {
      case 'completed':
        return l10n.tripComplete;
      case 'cancelled':
        return l10n.rideStatusCancelled;
      case 'pending':
        return l10n.rideStatusSearching;
      case 'assigned':
        return l10n.rideStatusDriverAssigned;
      case 'arrived':
        return l10n.rideStatusDriverArrived;
      case 'in_progress':
        return l10n.rideStatusInProgress;
      case 'marketplace':
        return l10n.marketplace;
      default:
        return ride.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusLabel(),
                          style: typo.labelSmall.copyWith(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${ride.createdAt.day}/${ride.createdAt.month}/${ride.createdAt.year}',
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accentL,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.location_on,
                            color: colors.accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.pickupAddress.split(',').first,
                              style: typo.bodyMedium.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ride.destinationAddress.split(',').first,
                              style: typo.bodySmall
                                  .copyWith(color: colors.textMid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (ride.fare != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '€${ride.fare!.toStringAsFixed(2)}',
                          style: typo.titleMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (ride.status == 'completed')
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/receipt/${ride.id}'),
                    icon: Icon(
                      Icons.receipt_long_outlined,
                      color: colors.text,
                      size: 20,
                    ),
                    label: Text(
                      'View receipt',
                      style: typo.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/report',
                      extra: ReportRouteArgs(ridesRowId: ride.id),
                    ),
                    icon: Icon(Icons.flag_outlined,
                        color: colors.error, size: 20),
                    label: Text(
                      l10n.ridesCardReportRide,
                      style: typo.labelLarge.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w700,
                      ),
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
