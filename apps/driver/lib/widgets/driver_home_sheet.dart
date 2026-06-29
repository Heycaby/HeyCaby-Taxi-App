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
import '../providers/driver_state_provider.dart';
import 'driver_home_live_rides_section.dart';
import 'driver_home_premium_style.dart';
import 'driver_progressive_verification_banner.dart';
import 'three_state_toggle.dart';

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
    final showLiveRidesSection =
        driver.appState == DriverAppState.onlineAvailable ||
            driver.activeRideId != null;
    final rides = scheduledAsync.valueOrNull ?? [];
    final openSwapsCount = swapFeedAsync.valueOrNull?.length;
    final feasibleCount = feasibleCountAsync.valueOrNull;
    final earnings = earningsAsync.valueOrNull;
    final todayRides =
        statsAsync.valueOrNull?.shiftRidesToday ?? earnings?.todayRides ?? 0;
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
                  ThreeStateToggle(
                    currentStatus: switch (driver.appState) {
                      DriverAppState.onBreak =>
                        DriverAvailabilityStatus.onBreak,
                      DriverAppState.onlineAvailable =>
                        DriverAvailabilityStatus.available,
                      _ => DriverAvailabilityStatus.offline,
                    },
                  ).driverFadeSlideIn(staggerIndex: 0),
                  const DriverProgressiveVerificationBanner(),
                  if (showLiveRidesSection) ...[
                    const SizedBox(height: DriverSpacing.lg),
                    DriverHomeLiveRidesSection(
                      colors: driverColors,
                      typography: driverTypo,
                      themeColors: colors,
                      themeTypography: typo,
                    ).driverFadeSlideIn(staggerIndex: 1),
                  ],
                  const SizedBox(height: DriverSpacing.lg),
                  _SectionLabel(
                    label: 'Ritten',
                    colors: colors,
                    typo: typo,
                  ).driverFadeSlideIn(staggerIndex: 2),
                  const SizedBox(height: DriverSpacing.sm),
                  _RidesActionGrid(
                    driverColors: driverColors,
                    colors: colors,
                    typo: typo,
                    scheduledCount: rides.length,
                    feasibleCount: feasibleCount,
                    todayRides: todayRides,
                    openSwapsCount: openSwapsCount,
                    returnTripsCount: returnTripsCount,
                    onScheduledTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/scheduled-rides');
                    },
                    onTodayTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/rides/today');
                    },
                    onRideSwapTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/ride-swap');
                    },
                    onReturnTripsTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/return-trips');
                    },
                  ).driverFadeSlideIn(staggerIndex: 3),
                  const SizedBox(height: DriverSpacing.lg),
                  _SectionLabel(
                    label: 'Instellingen',
                    colors: colors,
                    typo: typo,
                  ).driverFadeSlideIn(staggerIndex: 4),
                  const SizedBox(height: DriverSpacing.sm),
                  _DriverSettingsList(
                    colors: colors,
                    driverColors: driverColors,
                    typo: typo,
                  ).driverFadeSlideIn(staggerIndex: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.colors,
    required this.typo,
  });

  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: typo.titleSmall.copyWith(
          color: colors.textMid,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RidesActionGrid extends StatelessWidget {
  const _RidesActionGrid({
    required this.driverColors,
    required this.colors,
    required this.typo,
    required this.scheduledCount,
    required this.feasibleCount,
    required this.todayRides,
    required this.openSwapsCount,
    required this.returnTripsCount,
    required this.onScheduledTap,
    required this.onTodayTap,
    required this.onRideSwapTap,
    required this.onReturnTripsTap,
  });

  final DriverColors driverColors;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final int scheduledCount;
  final int? feasibleCount;
  final int todayRides;
  final int? openSwapsCount;
  final int? returnTripsCount;
  final VoidCallback onScheduledTap;
  final VoidCallback onTodayTap;
  final VoidCallback onRideSwapTap;
  final VoidCallback onReturnTripsTap;

  @override
  Widget build(BuildContext context) {
    final scheduledSubtitle = feasibleCount != null
        ? '$feasibleCount passend'
        : '$scheduledCount gepland';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _RideActionCard(
                colors: colors,
                driverColors: driverColors,
                typo: typo,
                icon: AppIcons.calendar,
                title: DriverStrings.scheduledRides,
                subtitle: scheduledSubtitle,
                onTap: onScheduledTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RideActionCard(
                colors: colors,
                driverColors: driverColors,
                typo: typo,
                icon: AppIcons.carFront,
                title: DriverStrings.today,
                subtitle:
                    todayRides == 0 ? 'Nog geen ritten' : '$todayRides ritten',
                onTap: onTodayTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RideActionCard(
                colors: colors,
                driverColors: driverColors,
                typo: typo,
                icon: AppIcons.swapHorizontal,
                title: DriverStrings.rideSwap,
                subtitle: openSwapsCount == null
                    ? 'Laden...'
                    : DriverStrings.rideSwapOpenCount(openSwapsCount!),
                onTap: onRideSwapTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RideActionCard(
                colors: colors,
                driverColors: driverColors,
                typo: typo,
                icon: AppIcons.arrowBack,
                title: DriverStrings.returnTrips,
                subtitle: returnTripsCount == null
                    ? 'Laden...'
                    : returnTripsCount == 0
                        ? 'Uit'
                        : '$returnTripsCount beschikbaar',
                onTap: onReturnTripsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RideActionCard extends StatelessWidget {
  const _RideActionCard({
    required this.colors,
    required this.driverColors,
    required this.typo,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DriverAccentRailCard(
      colors: driverColors,
      onTap: onTap,
      padding: const EdgeInsets.all(DriverSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: colors.textMid,
              size: 25,
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverSettingsList extends StatefulWidget {
  const _DriverSettingsList({
    required this.colors,
    required this.driverColors,
    required this.typo,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;

  @override
  State<_DriverSettingsList> createState() => _DriverSettingsListState();
}

class _DriverSettingsListState extends State<_DriverSettingsList> {
  bool _autoAcceptReturnRides = false;
  bool _showTodayOnMap = true;

  void _setAutoAcceptReturnRides(bool value) {
    HapticService.selectionClick();
    setState(() => _autoAcceptReturnRides = value);
  }

  void _setShowTodayOnMap(bool value) {
    HapticService.selectionClick();
    setState(() => _showTodayOnMap = value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.colors.card,
        borderRadius: DriverRadius.lgAll,
        border: Border.all(
          color: widget.colors.border.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: DriverHomePremiumStyle.tileShadow(widget.driverColors),
      ),
      child: Column(
        children: [
          _SettingsSwitchRow(
            label: 'Retourritten automatisch accepteren',
            value: _autoAcceptReturnRides,
            onChanged: _setAutoAcceptReturnRides,
            colors: widget.colors,
            typo: widget.typo,
          ),
          Divider(
            height: 1,
            thickness: 0.6,
            color: widget.colors.border.withValues(alpha: 0.75),
            indent: DriverSpacing.md,
            endIndent: DriverSpacing.md,
          ),
          _SettingsSwitchRow(
            label: 'Ritten vandaag op kaart tonen',
            value: _showTodayOnMap,
            onChanged: _setShowTodayOnMap,
            colors: widget.colors,
            typo: widget.typo,
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.colors,
    required this.typo,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DriverRadius.lg),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DriverSpacing.md,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: colors.success,
              activeTrackColor: colors.success.withValues(alpha: 0.24),
              inactiveThumbColor: colors.card,
              inactiveTrackColor: colors.border,
            ),
          ],
        ),
      ),
    );
  }
}
