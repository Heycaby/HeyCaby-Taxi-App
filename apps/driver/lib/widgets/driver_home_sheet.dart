import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../theme/driver_motion_presets.dart';
import '../ui/driver_accent_rail_card.dart';
import '../providers/driver_data_providers.dart';
import 'ride_swap_feed_content.dart';
import '../providers/driver_state_provider.dart';
import 'driver_home_live_rides_section.dart';
import 'driver_home_premium_style.dart';
import 'driver_progressive_verification_banner.dart';
import 'three_state_toggle.dart';

void _showRideSwapHelp(
  BuildContext context,
  HeyCabyColorTokens colors,
  HeyCabyTypography typo,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        DriverStrings.rideSwapHowTitle,
        style: typo.titleMedium
            .copyWith(color: colors.text, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: RideSwapHowIntroSection(
          colors: colors,
          typo: typo,
          includePullHint: false,
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
    const navBarClearance = 72.0;
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypo = DriverTypography.fromTheme(typo);
    final driver = ref.watch(driverStateProvider);
    final scheduledAsync = ref.watch(scheduledRidesProvider);
    final feasibleCountAsync = ref.watch(feasibleScheduledCountProvider);
    final earningsAsync = ref.watch(driverEarningsProvider);
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final returnTripsAsync = ref.watch(filteredReturnTripsProvider);
    final swapFeedAsync = ref.watch(rideSwapFeedProvider);
    final rides = scheduledAsync.valueOrNull ?? [];
    final openSwapsCount = swapFeedAsync.valueOrNull?.length;
    final feasibleCount = feasibleCountAsync.valueOrNull;
    final earnings = earningsAsync.valueOrNull;
    final todayRides = statsAsync.valueOrNull?.shiftRidesToday ??
        earnings?.todayRides ??
        0;
    final returnTripsCount = returnTripsAsync.valueOrNull?.length;

    return Container(
      decoration: BoxDecoration(
        gradient: DriverHomePremiumStyle.sheetTopGradient,
        borderRadius: DriverRadius.sheetTop,
        boxShadow: DriverShadows.floating(driverColors),
      ),
      child: ClipRRect(
        borderRadius: DriverRadius.sheetTop,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context).padding.bottom + navBarClearance + 20,
          ),
          children: [
            DriverHomeSheetHandle(colors: driverColors),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.screenEdge,
              ),
              child: Column(
                children: [
                  DriverHomeLiveRidesSection(
                    colors: driverColors,
                    typography: driverTypo,
                    themeColors: colors,
                    themeTypography: typo,
                  ).driverFadeSlideIn(staggerIndex: 0),
                  ThreeStateToggle(
                    currentStatus: switch (driver.appState) {
                      DriverAppState.onBreak =>
                        DriverAvailabilityStatus.onBreak,
                      DriverAppState.onlineAvailable =>
                        DriverAvailabilityStatus.available,
                      _ => DriverAvailabilityStatus.offline,
                    },
                  ).driverFadeSlideIn(staggerIndex: 1),
                  const DriverProgressiveVerificationBanner(),
                  const SizedBox(height: DriverSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 158,
                          child: _ScheduledRidesCard(
                            driverColors: driverColors,
                            rideCount: rides.length,
                            feasibleCount: feasibleCount,
                            compact: true,
                            colors: colors,
                            typo: typo,
                            onTap: () {
                              HapticService.selectionClick();
                              context.push('/driver/scheduled-rides');
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 158,
                          child: _RideSwapHomeCard(
                            driverColors: driverColors,
                            openCount: openSwapsCount,
                            colors: colors,
                            typo: typo,
                            onTap: () {
                              HapticService.selectionClick();
                              context.push('/driver/ride-swap');
                            },
                            onInfoTap: () =>
                                _showRideSwapHelp(context, colors, typo),
                          ),
                        ),
                      ),
                    ],
                  ).driverFadeSlideIn(staggerIndex: 2),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 138,
                          child: _ReturnTripsCard(
                            driverColors: driverColors,
                            count: returnTripsCount,
                            colors: colors,
                            typo: typo,
                            onTap: () => context.push('/driver/return-trips'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 138,
                          child: _StatCard(
                            driverColors: driverColors,
                            label: DriverStrings.todaysRides,
                            value: '$todayRides',
                            stars: 0,
                            leadingIcon: AppIcons.carFront,
                            showChevron: true,
                            colors: colors,
                            typo: typo,
                            onTap: () {
                              HapticService.selectionClick();
                              context.push('/driver/rides/today');
                            },
                          ),
                        ),
                      ),
                    ],
                  ).driverFadeSlideIn(staggerIndex: 3),
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
  final DriverColors driverColors;
  final int? count;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ReturnTripsCard({
    required this.driverColors,
    required this.count,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final driverTypo = DriverTypography.fromTheme(typo);
    return DriverAccentRailCard(
      colors: driverColors,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DriverHomeIconOrb(
                icon: AppIcons.arrowBack,
                colors: driverColors,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Text(
                  DriverStrings.returnTrips,
                  maxLines: 2,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                color: driverColors.primary.withValues(alpha: 0.55),
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          DriverHomeMetricText(
            value: count == null ? '—' : '$count',
            colors: driverColors,
            typography: driverTypo,
          ),
        ],
      ),
    );
  }
}

class _ScheduledRidesCard extends StatelessWidget {
  final DriverColors driverColors;
  final int rideCount;
  final int? feasibleCount;
  final bool compact;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ScheduledRidesCard({
    required this.driverColors,
    required this.rideCount,
    this.feasibleCount,
    this.compact = false,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gap = compact ? DriverSpacing.sm : DriverSpacing.md;
    final subtitle = feasibleCount != null
        ? (feasibleCount == 1
            ? '1 ride you can take'
            : '$feasibleCount rides you can take')
        : (rideCount == 1
            ? '1 ride available in your area'
            : '$rideCount rides available in your area');

    return DriverAccentRailCard(
      colors: driverColors,
      onTap: onTap,
      child: Row(
        children: [
          DriverHomeIconOrb(
            icon: AppIcons.calendar,
            colors: driverColors,
            size: 42,
            iconSize: 20,
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.scheduledRides,
                  maxLines: compact ? 2 : null,
                  style: (compact ? typo.bodyMedium : typo.titleMedium).copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            color: driverColors.primary.withValues(alpha: 0.55),
            size: compact ? 18 : 22,
          ),
        ],
      ),
    );
  }
}

class _RideSwapHomeCard extends StatelessWidget {
  final DriverColors driverColors;
  final int? openCount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _RideSwapHomeCard({
    required this.driverColors,
    required this.openCount,
    required this.colors,
    required this.typo,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return DriverAccentRailCard(
      colors: driverColors,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.md,
        DriverSpacing.sm,
        DriverSpacing.sm,
        DriverSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DriverHomeIconOrb(
                icon: AppIcons.swapHorizontal,
                colors: driverColors,
                size: 42,
                iconSize: 20,
              ),
              const Spacer(),
              Material(
                color: driverColors.primary.withValues(alpha: 0.08),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onInfoTap,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: driverColors.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            DriverStrings.rideSwap,
            maxLines: 2,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            openCount == null
                ? '…'
                : DriverStrings.rideSwapOpenCount(openCount!),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: typo.bodySmall.copyWith(
              color: colors.textMid,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              AppIcons.chevronRight,
              color: driverColors.primary.withValues(alpha: 0.55),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final DriverColors driverColors;
  final String label;
  final String value;
  final int stars;
  final IconData? leadingIcon;
  final bool showChevron;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onTap;

  const _StatCard({
    required this.driverColors,
    required this.label,
    required this.value,
    required this.stars,
    this.leadingIcon,
    required this.showChevron,
    required this.colors,
    required this.typo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final driverTypo = DriverTypography.fromTheme(typo);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            children: [
              if (leadingIcon != null) ...[
                DriverHomeIconOrb(
                  icon: leadingIcon!,
                  colors: driverColors,
                  size: 42,
                  iconSize: 20,
                ),
                const SizedBox(width: DriverSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: driverColors.primary.withValues(alpha: 0.55),
                ),
            ],
          ),
          const Spacer(),
          DriverHomeMetricText(
            value: value,
            colors: driverColors,
            typography: driverTypo,
          ),
          if (stars > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < stars ? AppIcons.star : AppIcons.starOff,
                  size: 14,
                  color: driverColors.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ],
      );

    return DriverAccentRailCard(
      colors: driverColors,
      onTap: onTap,
      child: content,
    );
  }
}
