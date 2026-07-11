import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../theme/driver_motion_presets.dart';
import '../ui/driver_accent_rail_card.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../providers/driver_taxi_terug_stats_provider.dart';
import '../services/driver_data_service.dart';
import 'driver_home_live_rides_section.dart';
import 'driver_home_premium_style.dart';
import 'driver_hub_saved_by_riders_section.dart';
import 'driver_progressive_verification_banner.dart';
import 'driver_ride_alert_readiness_card.dart';
import 'driver_taxi_terug_stats_card.dart';
import 'three_state_toggle.dart';

/// Bottom sheet on driver home. Offline state: scheduled rides, stats, community.
class DriverHomeSheet extends ConsumerWidget {
  const DriverHomeSheet({
    super.key,
    required this.controller,
    required this.colors,
    required this.typo,
    required this.onOpenDriverHub,
  });

  final ScrollController controller;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onOpenDriverHub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const navBarClearance = 72.0;
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypo = DriverTypography.fromTheme(typo);
    final driver = ref.watch(driverStateProvider);
    final scheduledAsync = ref.watch(scheduledRidesProvider);
    final earningsAsync = ref.watch(driverEarningsProvider);
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final returnTripsAsync = ref.watch(filteredReturnTripsProvider);
    final returnModeAsync = ref.watch(driverReturnModeProvider);
    final taxiTerugStatsAsync = ref.watch(driverTaxiTerugStatsProvider);
    final upcomingAsync = ref.watch(upcomingRidesProvider);
    final billingStatusAsync = ref.watch(driverBillingStatusProvider);
    final showLiveRidesSection =
        driver.appState == DriverAppState.onlineAvailable ||
            driver.activeRideId != null;
    final rides = scheduledAsync.valueOrNull ?? [];
    final earnings = earningsAsync.valueOrNull;
    final todayRides =
        statsAsync.valueOrNull?.shiftRidesToday ?? earnings?.todayRides ?? 0;
    final upcomingRides = upcomingAsync.valueOrNull ?? [];
    final upcomingCount = upcomingRides.length;
    final returnTripsCount = returnTripsAsync.valueOrNull?.length;
    final returnMode = returnModeAsync.valueOrNull;

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: DriverRadius.sheetTop,
      tintColor: colors.card,
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
                  const SizedBox(height: DriverSpacing.md),
                  if (billingStatusAsync.valueOrNull?['ride_requests_paused'] ==
                      true) ...[
                    _PlatformRidesPausedCard(
                      colors: colors,
                      driverColors: driverColors,
                      typo: typo,
                      onViewSettlementDetails: () {
                        HapticService.selectionClick();
                        context.push('/driver/billing');
                      },
                    ).driverFadeSlideIn(staggerIndex: 1),
                    const SizedBox(height: DriverSpacing.md),
                  ],
                  const DriverRideAlertReadinessCard()
                      .driverFadeSlideIn(staggerIndex: 1),
                  const SizedBox(height: DriverSpacing.lg),
                  if (driver.activeRideId == null) ...[
                    _ReturnModeCard(
                      colors: colors,
                      driverColors: driverColors,
                      typo: typo,
                      status: returnMode,
                      loading: returnModeAsync.isLoading,
                      returnTripsCount: returnTripsCount,
                      onManage: () {
                        HapticService.selectionClick();
                        context.push('/driver/return-trips');
                      },
                      onActivate: () async {
                        HapticService.mediumTap();
                        final result = await ref
                            .read(driverDataServiceProvider)
                            .activateReturnMode(
                              destinationLabel: returnMode?.destinationLabel,
                              destinationZoneId: returnMode?.destinationZoneId,
                              destinationLat: returnMode?.destinationLat,
                              destinationLng: returnMode?.destinationLng,
                              pickupRadiusKm: returnMode?.pickupRadiusKm,
                              returnDiscountPct:
                                  (returnMode?.returnDiscountPct ?? 0) > 0
                                      ? returnMode?.returnDiscountPct
                                      : 15,
                            );
                        ref.invalidate(driverReturnModeProvider);
                        ref.invalidate(driverProfileProvider);
                        ref.invalidate(driverRateProfilesProvider);
                        ref.invalidate(activeRateProfileProvider);
                        ref.invalidate(filteredReturnTripsProvider);
                        if (!context.mounted || result.ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.activationErrorMessage),
                          ),
                        );
                      },
                      onDisable: () async {
                        HapticService.selectionClick();
                        await ref
                            .read(driverDataServiceProvider)
                            .disableReturnMode();
                        ref.invalidate(driverReturnModeProvider);
                      },
                      onPlanTrip: () {
                        HapticService.selectionClick();
                        context.push('/driver/journey-intent');
                      },
                    ).driverFadeSlideIn(staggerIndex: 1),
                    const SizedBox(height: DriverSpacing.md),
                    DriverTaxiTerugStatsCard(
                      colors: colors,
                      driverColors: driverColors,
                      typo: driverTypo,
                      stats: taxiTerugStatsAsync.valueOrNull,
                      loading: taxiTerugStatsAsync.isLoading,
                    ).driverFadeSlideIn(staggerIndex: 2),
                    const SizedBox(height: DriverSpacing.lg),
                  ],
                  _DriverHubEntryCard(
                    colors: colors,
                    driverColors: driverColors,
                    typo: typo,
                    onTap: onOpenDriverHub,
                  ).driverFadeSlideIn(staggerIndex: 2),
                  const DriverHomeSavedByRidersCard()
                      .driverFadeSlideIn(staggerIndex: 2),
                  const DriverProgressiveVerificationBanner(),
                  if (showLiveRidesSection) ...[
                    const SizedBox(height: DriverSpacing.lg),
                    DriverHomeLiveRidesSection(
                      colors: driverColors,
                      typography: driverTypo,
                      themeColors: colors,
                      themeTypography: typo,
                    ).driverFadeSlideIn(staggerIndex: 3),
                  ],
                  const SizedBox(height: DriverSpacing.lg),
                  _SectionLabel(
                    label: DriverStrings.homeRidesSection,
                    colors: colors,
                    typo: typo,
                  ).driverFadeSlideIn(staggerIndex: 4),
                  const SizedBox(height: DriverSpacing.sm),
                  _RidesActionGrid(
                    driverColors: driverColors,
                    colors: colors,
                    typo: typo,
                    scheduledCount: rides.length,
                    todayRides: todayRides,
                    upcomingCount: upcomingCount,
                    returnTripsCount: returnTripsCount,
                    onScheduledTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/scheduled-rides');
                    },
                    onTodayTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/rides/today?filter=upcoming');
                    },
                    onReturnTripsTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/return-trips');
                    },
                    onTaxiThruTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/taxi-thru');
                    },
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

class _PlatformRidesPausedCard extends StatelessWidget {
  const _PlatformRidesPausedCard({
    required this.colors,
    required this.driverColors,
    required this.typo,
    required this.onViewSettlementDetails,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;
  final VoidCallback onViewSettlementDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.28),
        ),
        boxShadow: DriverHomePremiumStyle.tileShadow(driverColors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(DriverRadius.md),
                ),
                child: Icon(
                  Icons.pause_circle_outline_rounded,
                  color: colors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.platformRidesPausedTitle,
                      style: typo.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.xs),
                    Text(
                      DriverStrings.platformRidesPausedBody,
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewSettlementDetails,
              icon: const Icon(Icons.account_balance_outlined, size: 19),
              label: Text(DriverStrings.platformRidesPausedCta),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.text,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                  color: colors.warning.withValues(alpha: 0.42),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DriverRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnModeCard extends StatelessWidget {
  const _ReturnModeCard({
    required this.colors,
    required this.driverColors,
    required this.typo,
    required this.status,
    required this.loading,
    required this.returnTripsCount,
    required this.onActivate,
    required this.onManage,
    required this.onDisable,
    required this.onPlanTrip,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;
  final DriverReturnModeStatus? status;
  final bool loading;
  final int? returnTripsCount;
  final Future<void> Function() onActivate;
  final VoidCallback onManage;
  final Future<void> Function() onDisable;
  final VoidCallback onPlanTrip;

  @override
  Widget build(BuildContext context) {
    final isActive = status?.enabled == true;
    final hasDestination = status?.hasDestination == true;
    final destination = status?.destinationDisplay;
    final hasMatches = isActive && (returnTripsCount ?? 0) > 0;
    final statusLabel = loading
        ? DriverStrings.loading
        : isActive && hasDestination
            ? DriverStrings.returnModeHeadingTo(destination!)
            : DriverStrings.returnModeOff;
    final body = loading
        ? DriverStrings.loading
        : isActive
            ? hasMatches
                ? DriverStrings.returnModeAvailableCount(returnTripsCount!)
                : DriverStrings.returnModeNoMatchesYet
            : status?.suggestTaxiTerug == true &&
                    status?.kmFromHome != null &&
                    hasDestination
                ? DriverStrings.returnModeSuggestBody(
                    status!.kmFromHome!,
                    destination!,
                  )
                : hasDestination
                    ? DriverStrings.returnModeHeadingHomeBody(destination!)
                    : DriverStrings.returnModeOffBody;
    final detail = isActive
        ? [
            DriverStrings.returnModeActiveBody(
              pickupRadiusKm: status?.pickupRadiusKm ?? 10,
            ),
            if (status?.kmFromHome != null)
              DriverStrings.returnModeKmFromHome(status!.kmFromHome!),
          ].join(' · ')
        : null;

    return InkWell(
      onTap: isActive ? onManage : null,
      borderRadius: DriverRadius.lgAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DriverSpacing.lg),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.55),
          borderRadius: DriverRadius.lgAll,
          border: Border.all(
            color: hasMatches
                ? colors.success.withValues(alpha: 0.42)
                : isActive
                    ? colors.success.withValues(alpha: 0.24)
                    : colors.border.withValues(alpha: 0.85),
            width: 1.2,
          ),
          boxShadow: DriverHomePremiumStyle.tileShadow(driverColors),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DriverRadius.md),
              ),
              child: Icon(
                AppIcons.arrowBack,
                color: colors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: DriverSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DriverStrings.returnMode,
                          style: typo.titleSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (hasMatches ? colors.success : colors.textMid)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: typo.labelSmall.copyWith(
                            color: hasMatches ? colors.success : colors.textMid,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DriverSpacing.xs),
                  Text(
                    body,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: DriverSpacing.xs),
                    Text(
                      detail,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: DriverSpacing.sm),
                  if (isActive)
                    Wrap(
                      spacing: DriverSpacing.sm,
                      runSpacing: DriverSpacing.xs,
                      children: [
                        _ReturnModeActionChip(
                          colors: colors,
                          typo: typo,
                          label: DriverStrings.returnModeManage,
                          filled: false,
                          onTap: onManage,
                        ),
                        _ReturnModeActionChip(
                          colors: colors,
                          typo: typo,
                          label: DriverStrings.returnModeDisable,
                          filled: false,
                          onTap: onDisable,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: loading ? null : onActivate,
                            icon: const Icon(Icons.route_rounded, size: 20),
                            label: Text(DriverStrings.returnModeActivateFull),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DriverSpacing.md,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(DriverRadius.md),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: DriverSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onPlanTrip,
                            icon: const Icon(Icons.edit_location_alt_rounded,
                                size: 18),
                            label: Text(DriverStrings.journeyIntentPlanTrip),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DriverSpacing.md,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(DriverRadius.md),
                              ),
                              side: BorderSide(
                                color: colors.accent.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _ReturnModeActionChip extends StatelessWidget {
  const _ReturnModeActionChip({
    required this.colors,
    required this.typo,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              filled ? colors.success : colors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colors.success.withValues(alpha: filled ? 0 : 0.22),
          ),
        ),
        child: Text(
          label,
          style: typo.labelSmall.copyWith(
            color: filled ? colors.onAccent : colors.success,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DriverHubEntryCard extends ConsumerWidget {
  const _DriverHubEntryCard({
    required this.colors,
    required this.driverColors,
    required this.typo,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRate = ref.watch(activeRateProfileProvider).valueOrNull;
    final earnings = ref.watch(driverEarningsProvider).valueOrNull;
    final perKm = activeRate == null
        ? DriverStrings.notSet
        : '€${activeRate.perKmRate.toStringAsFixed(2)}/km';
    final profileName = activeRate?.profileName ?? DriverStrings.activeTariff;
    final today = earnings?.formatEuros(earnings.todayEuros) ?? '€0.00';

    return DriverAccentRailCard(
      colors: driverColors,
      onTap: () {
        HapticService.mediumTap();
        onTap();
      },
      padding: const EdgeInsets.all(DriverSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  AppIcons.hubGrid,
                  color: colors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.driverHub,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DriverStrings.driverHubHomeSubtitle,
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
              Icon(
                Icons.arrow_forward_rounded,
                color: colors.accent,
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HubEntryMetric(
                  label: DriverStrings.driverHubCurrentTariff,
                  value: perKm,
                  helper: profileName,
                  colors: colors,
                  typo: typo,
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: _HubEntryMetric(
                  label: DriverStrings.driverHubToday,
                  value: today,
                  helper: DriverStrings.earnedLabel,
                  colors: colors,
                  typo: typo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubEntryMetric extends StatelessWidget {
  const _HubEntryMetric({
    required this.label,
    required this.value,
    required this.helper,
    required this.colors,
    required this.typo,
  });

  final String label;
  final String value;
  final String helper;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.labelSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.labelSmall.copyWith(
              color: colors.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    required this.todayRides,
    required this.upcomingCount,
    required this.returnTripsCount,
    required this.onScheduledTap,
    required this.onTodayTap,
    required this.onReturnTripsTap,
    required this.onTaxiThruTap,
  });

  final DriverColors driverColors;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final int scheduledCount;
  final int todayRides;
  final int upcomingCount;
  final int? returnTripsCount;
  final VoidCallback onScheduledTap;
  final VoidCallback onTodayTap;
  final VoidCallback onReturnTripsTap;
  final VoidCallback onTaxiThruTap;

  @override
  Widget build(BuildContext context) {
    final scheduledSubtitle =
        DriverStrings.homePlannedScheduledCount(scheduledCount);
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
                subtitle: upcomingCount > 0
                    ? DriverStrings.homeUpcomingCount(upcomingCount)
                    : DriverStrings.homeTodayRidesCount(todayRides),
                badgeCount: upcomingCount > 0 ? upcomingCount : null,
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
                icon: AppIcons.arrowBack,
                title: DriverStrings.returnTrips,
                subtitle: returnTripsCount == null
                    ? DriverStrings.loading
                    : returnTripsCount == 0
                        ? DriverStrings.off
                        : DriverStrings.homeAvailableCount(returnTripsCount!),
                onTap: onReturnTripsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RideActionCard(
                colors: colors,
                driverColors: driverColors,
                typo: typo,
                icon: Icons.travel_explore_rounded,
                title: DriverStrings.taxiThruTitle,
                subtitle: DriverStrings.taxiThruTitle,
                onTap: onTaxiThruTap,
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
    this.badgeCount,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? badgeCount;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: colors.textMid,
                  size: 25,
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: typo.labelSmall.copyWith(
                        color: colors.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DriverSpacing.xl),
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
