import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import 'home_sheet/home_sheet_apple_styles.dart';
import 'three_state_toggle.dart';

String _initialsFromId(String? id) {
  if (id == null || id.length < 2) return '??';
  return id.substring(0, 2).toUpperCase();
}

void _showRideSwapHelp(
  BuildContext context,
  HeyCabyColorTokens colors,
  HeyCabyTypography typo,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.card,
      title: Text(
        DriverStrings.rideSwap,
        style: typo.titleMedium
            .copyWith(color: colors.text, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Text(
          DriverStrings.rideSwapHelpBody,
          style: typo.bodyMedium.copyWith(color: colors.text, height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(DriverStrings.cancel,
              style: TextStyle(color: colors.accent)),
        ),
      ],
    ),
  );
}

/// Bottom sheet on driver home. Offline state: scheduled rides, stats, community.
class DriverHomeSheet extends ConsumerWidget {
  const DriverHomeSheet({
    super.key,
    required this.controller,
    required this.colors,
    required this.typo,
  });

  final ScrollController controller;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverStateProvider);
    final scheduledAsync = ref.watch(scheduledRidesProvider);
    final feasibleCountAsync = ref.watch(feasibleScheduledCountProvider);
    final earningsAsync = ref.watch(driverEarningsProvider);
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final latestPostAsync = ref.watch(latestCommunityPostProvider);
    final returnTripsAsync = ref.watch(filteredReturnTripsProvider);
    final swapFeedAsync = ref.watch(rideSwapFeedProvider);
    final rides = scheduledAsync.valueOrNull ?? [];
    final openSwapsCount = swapFeedAsync.valueOrNull?.length;
    final feasibleCount = feasibleCountAsync.valueOrNull;
    final todayRides = statsAsync.valueOrNull?.shiftRidesToday ??
        earningsAsync.valueOrNull?.todayRides ??
        0;
    final latestPost = latestPostAsync.valueOrNull;
    final returnTripsCount = returnTripsAsync.valueOrNull?.length;

    const sheetRadius = BorderRadius.vertical(top: Radius.circular(20));
    return Container(
      decoration: BoxDecoration(
        color: HomeSheetAppleStyles.groupedBackground(colors),
        borderRadius: sheetRadius,
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: sheetRadius,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: HomeSheetAppleStyles.separatorTone(colors)
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ThreeStateToggle(
                    currentStatus: switch (driver.appState) {
                      DriverAppState.onBreak =>
                        DriverAvailabilityStatus.onBreak,
                      DriverAppState.onlineAvailable =>
                        DriverAvailabilityStatus.available,
                      _ => DriverAvailabilityStatus.offline,
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ScheduledRidesCard(
                          rideCount: rides.length,
                          feasibleCount: feasibleCount,
                          compact: true,
                          colors: colors,
                          typo: typo,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/driver/scheduled-rides');
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _RideSwapHomeCard(
                          openCount: openSwapsCount,
                          colors: colors,
                          typo: typo,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/driver/ride-swap');
                          },
                          onInfoTap: () =>
                              _showRideSwapHelp(context, colors, typo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ReturnTripsCard(
                          count: returnTripsCount,
                          colors: colors,
                          typo: typo,
                          onTap: () => context.push('/driver/return-trips'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          label: DriverStrings.todaysRides,
                          value: '$todayRides',
                          stars: 0,
                          showChevron: false,
                          colors: colors,
                          typo: typo,
                          onTap: null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CommunityPreviewCard(
                    authorInitials: _initialsFromId(latestPost?.authorDriverId),
                    postPreview: latestPost?.body ?? 'No recent posts',
                    colors: colors,
                    typo: typo,
                    onTap: () => context.go('/driver/community'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnTripsCard extends StatelessWidget {
  final int? count;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ReturnTripsCard({
    required this.count,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.accent.withValues(alpha: 0.08),
        highlightColor: colors.accent.withValues(alpha: 0.04),
        child: Ink(
          decoration: HomeSheetAppleStyles.cardDecoration(colors),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DriverStrings.returnTrips,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Icon(AppIcons.arrowBack, color: colors.accent, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  count == null ? '—' : '$count',
                  style: typo.displayMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduledRidesCard extends StatelessWidget {
  final int rideCount;
  final int? feasibleCount;
  final bool compact;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ScheduledRidesCard({
    required this.rideCount,
    this.feasibleCount,
    this.compact = false,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 14.0 : 18.0;
    final iconSize = compact ? 40.0 : 44.0;
    final iconInner = compact ? 20.0 : 22.0;
    final gap = compact ? 12.0 : 16.0;
    const radius = 20.0;
    final subtitle = feasibleCount != null
        ? (feasibleCount == 1
            ? '1 ride you can take'
            : '$feasibleCount rides you can take')
        : (rideCount == 1
            ? '1 ride available in your area'
            : '$rideCount rides available in your area');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.accent.withValues(alpha: 0.08),
        highlightColor: colors.accent.withValues(alpha: 0.04),
        child: Ink(
          decoration: HomeSheetAppleStyles.cardDecoration(colors),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  alignment: Alignment.center,
                  decoration: HomeSheetAppleStyles.iconWell(colors.accent),
                  child: Icon(AppIcons.calendar,
                      color: colors.accent, size: iconInner),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DriverStrings.scheduledRides,
                        maxLines: compact ? 2 : null,
                        style: (compact ? typo.bodyMedium : typo.titleMedium)
                            .copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: compact ? 2 : null,
                        overflow:
                            compact ? TextOverflow.ellipsis : TextOverflow.clip,
                        style: typo.bodySmall.copyWith(
                          color: colors.textSoft,
                          fontSize: compact ? 12 : null,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight,
                    color: colors.textSoft.withValues(alpha: 0.7),
                    size: compact ? 18 : 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideSwapHomeCard extends StatelessWidget {
  final int? openCount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _RideSwapHomeCard({
    required this.openCount,
    required this.colors,
    required this.typo,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.accent.withValues(alpha: 0.08),
        highlightColor: colors.accent.withValues(alpha: 0.04),
        child: Ink(
          decoration: HomeSheetAppleStyles.cardDecoration(colors),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: HomeSheetAppleStyles.iconWell(colors.accent),
                      child: Icon(AppIcons.swapHorizontal,
                          color: colors.accent, size: 20),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        style: IconButton.styleFrom(
                          foregroundColor: colors.textSoft,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(Icons.info_outline_rounded,
                            size: 20,
                            color: colors.textSoft.withValues(alpha: 0.85)),
                        tooltip: DriverStrings.rideSwap,
                        onPressed: onInfoTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  DriverStrings.rideSwap,
                  maxLines: 2,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  openCount == null
                      ? '…'
                      : DriverStrings.rideSwapOpenCount(openCount!),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(AppIcons.chevronRight,
                      color: colors.textSoft.withValues(alpha: 0.7), size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final int stars;
  final bool showChevron;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.stars,
    required this.showChevron,
    required this.colors,
    required this.typo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showChevron)
            Align(
              alignment: Alignment.topRight,
              child: Icon(AppIcons.chevronRight,
                  size: 18, color: colors.textSoft.withValues(alpha: 0.7)),
            ),
          Text(
            label,
            style: typo.labelSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: typo.headingMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
              fontSize: 32,
              letterSpacing: -0.5,
              height: 1.05,
            ),
          ),
          if (stars > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < stars ? AppIcons.star : AppIcons.starOff,
                  size: 14,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: HomeSheetAppleStyles.cardDecoration(colors),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.accent.withValues(alpha: 0.08),
        highlightColor: colors.accent.withValues(alpha: 0.04),
        child: Ink(
          decoration: HomeSheetAppleStyles.cardDecoration(colors),
          child: content,
        ),
      ),
    );
  }
}

class _CommunityPreviewCard extends StatelessWidget {
  final String authorInitials;
  final String postPreview;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _CommunityPreviewCard({
    required this.authorInitials,
    required this.postPreview,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.accent.withValues(alpha: 0.08),
        highlightColor: colors.accent.withValues(alpha: 0.04),
        child: Ink(
          decoration: HomeSheetAppleStyles.cardDecoration(colors),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.accent.withValues(alpha: 0.18),
                        colors.accent.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    authorInitials,
                    style: typo.titleMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            DriverStrings.driverTalk,
                            style: typo.titleMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.accentL.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DriverStrings.community,
                              style: typo.labelSmall.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        postPreview,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight,
                    color: colors.textSoft.withValues(alpha: 0.65), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
