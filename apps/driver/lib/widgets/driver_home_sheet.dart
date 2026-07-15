import 'dart:async';

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
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_data_service.dart';
import '../providers/driver_ride_line_provider.dart';
import 'driver_missed_opportunities_card.dart';
import 'driver_home_live_rides_section.dart';
import 'driver_home_premium_style.dart';
import 'driver_progressive_verification_banner.dart';
import 'driver_ride_alert_readiness_card.dart';
import 'driver_taxi_terug_wizard_sheet.dart';
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
    final scheduledCountAsync = ref.watch(scheduledRidesCountProvider);
    final returnTripsAsync = ref.watch(filteredReturnTripsProvider);
    final returnModeAsync = ref.watch(driverReturnModeProvider);
    final upcomingAsync = ref.watch(upcomingRidesProvider);
    final todayRidesCount = ref.watch(todayRidesCountProvider);
    final taxiThruCountAsync = ref.watch(driverTaxiThruPostsCountProvider);
    final billingStatusAsync = ref.watch(driverBillingStatusProvider);
    final rideLineAsync = ref.watch(driverRideLineProvider);
    final showLiveRidesSection =
        driver.appState == DriverAppState.onlineAvailable ||
            driver.appState == DriverAppState.onBreak ||
            driver.activeRideId != null ||
            (rideLineAsync.valueOrNull?.hasNext ?? false);
    final scheduledCount = scheduledCountAsync.valueOrNull ?? 0;
    final todayRides = todayRidesCount;
    final upcomingRides = upcomingAsync.valueOrNull ?? [];
    final upcomingCount = upcomingRides.length;
    final taxiThruCount = taxiThruCountAsync.valueOrNull ?? 0;
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
                  const DriverRideAlertReadinessCard()
                      .driverFadeSlideIn(staggerIndex: 1),
                  const SizedBox(height: DriverSpacing.md),
                  _DriverSheetInsetGroup(
                    colors: colors,
                    children: [
                      _TariffHubStrip(
                        colors: colors,
                        typo: typo,
                        onOpenHub: onOpenDriverHub,
                      ),
                      if (driver.activeRideId == null)
                        _ReturnModeRow(
                          colors: colors,
                          typo: typo,
                          status: returnMode,
                          loading: returnModeAsync.isLoading,
                          returnTripsCount: returnTripsCount,
                          onOpenMatches: () {
                            HapticService.selectionClick();
                            context.push('/driver/return-trips');
                          },
                          onManage: () {
                            HapticService.selectionClick();
                            unawaited(showDriverTaxiTerugWizard(context, ref));
                          },
                          onActivate: () async {
                            HapticService.mediumTap();
                            await showDriverTaxiTerugWizard(context, ref);
                          },
                          onDisable: () async {
                            HapticService.selectionClick();
                            final confirmed = await showModalBottomSheet<bool>(
                              context: context,
                              showDragHandle: true,
                              builder: (sheetContext) => SafeArea(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(DriverSpacing.lg),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        DriverStrings.returnModeDisableTitle,
                                        style: typo.titleLarge.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: DriverSpacing.sm),
                                      Text(DriverStrings.returnModeDisableBody),
                                      const SizedBox(height: DriverSpacing.lg),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(sheetContext, true),
                                        child: Text(
                                          DriverStrings
                                              .returnModeDisableConfirm,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(sheetContext, false),
                                        child: Text(DriverStrings.notNow),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            if (confirmed != true) return;
                            final result = await ref
                                .read(driverDataServiceProvider)
                                .disableReturnMode();
                            ref.invalidate(driverReturnModeProvider);
                            if (context.mounted && !result.ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.activationErrorMessage,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ).driverFadeSlideIn(staggerIndex: 2),
                  if (showLiveRidesSection) ...[
                    const SizedBox(height: DriverSpacing.md),
                    DriverHomeLiveRidesSection(
                      colors: driverColors,
                      typography: driverTypo,
                      themeColors: colors,
                      themeTypography: typo,
                    ).driverFadeSlideIn(staggerIndex: 3),
                    DriverMissedOpportunitiesCard(
                      colors: colors,
                      typo: typo,
                    ).driverFadeSlideIn(staggerIndex: 4),
                  ],
                  const SizedBox(height: DriverSpacing.md),
                  _RideQuickLinksRow(
                    colors: colors,
                    driverColors: driverColors,
                    typo: typo,
                    scheduledCount: scheduledCount,
                    scheduledCountLoading: scheduledCountAsync.isLoading,
                    todayRides: todayRides,
                    upcomingCount: upcomingCount,
                    taxiThruCount: taxiThruCount,
                    taxiThruCountLoading: taxiThruCountAsync.isLoading,
                    onScheduledTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/scheduled-rides');
                    },
                    onTodayTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/rides/today?filter=upcoming');
                    },
                    onTaxiThruTap: () {
                      HapticService.selectionClick();
                      context.push('/driver/taxi-thru');
                    },
                  ).driverFadeSlideIn(staggerIndex: 4),
                  if (billingStatusAsync.valueOrNull?['ride_requests_paused'] ==
                      true) ...[
                    const SizedBox(height: DriverSpacing.md),
                    _PlatformRidesPausedCard(
                      colors: colors,
                      driverColors: driverColors,
                      typo: typo,
                      onViewSettlementDetails: () {
                        HapticService.selectionClick();
                        context.push('/driver/billing');
                      },
                    ).driverFadeSlideIn(staggerIndex: 5),
                  ],
                  const DriverProgressiveVerificationBanner(),
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

class _DriverSheetInsetGroup extends StatelessWidget {
  const _DriverSheetInsetGroup({
    required this.colors,
    required this.children,
  });

  final HeyCabyColorTokens colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: colors.border.withValues(alpha: 0.55),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm + 2,
          ),
          child: children[i],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.52),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _TariffHubStrip extends ConsumerWidget {
  const _TariffHubStrip({
    required this.colors,
    required this.typo,
    required this.onOpenHub,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onOpenHub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRate = ref.watch(activeRateProfileProvider).valueOrNull;
    final perKm = activeRate == null
        ? DriverStrings.notSet
        : '€${activeRate.perKmRate.toStringAsFixed(2)}/km';
    final profileName = activeRate?.profileName ?? DriverStrings.activeTariff;

    return InkWell(
      onTap: () {
        HapticService.mediumTap();
        onOpenHub();
      },
      borderRadius: BorderRadius.circular(DriverRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$perKm · $profileName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.titleSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              DriverStrings.driverHub,
              style: typo.labelLarge.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.accent,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnModeRow extends StatelessWidget {
  const _ReturnModeRow({
    required this.colors,
    required this.typo,
    required this.status,
    required this.loading,
    required this.returnTripsCount,
    required this.onOpenMatches,
    required this.onActivate,
    required this.onManage,
    required this.onDisable,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverReturnModeStatus? status;
  final bool loading;
  final int? returnTripsCount;
  final VoidCallback onOpenMatches;
  final Future<void> Function() onActivate;
  final VoidCallback onManage;
  final Future<void> Function() onDisable;

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

    void onRowTap() {
      if (loading) return;
      if (!isActive) {
        unawaited(onActivate());
        return;
      }
      if (hasMatches) {
        onOpenMatches();
      } else {
        onManage();
      }
    }

    return InkWell(
      onTap: onRowTap,
      borderRadius: BorderRadius.circular(DriverRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.arrowBack,
                color: colors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: DriverSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverStrings.returnMode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DriverSpacing.xs),
            if (isActive) ...[
              if (hasMatches)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    returnTripsCount!.toString(),
                    style: typo.labelSmall.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => unawaited(onDisable()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, DriverSpacing.touchTarget),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.textMid,
                ),
                child: Text(
                  DriverStrings.returnModeDisable,
                  style: typo.labelSmall.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMid,
                size: 22,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.textMid.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: loading ? null : () => unawaited(onActivate()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, DriverSpacing.touchTarget),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  DriverStrings.returnModeActivate,
                  style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RideQuickLinksRow extends StatelessWidget {
  const _RideQuickLinksRow({
    required this.colors,
    required this.driverColors,
    required this.typo,
    required this.scheduledCount,
    required this.scheduledCountLoading,
    required this.todayRides,
    required this.upcomingCount,
    required this.taxiThruCount,
    required this.taxiThruCountLoading,
    required this.onScheduledTap,
    required this.onTodayTap,
    required this.onTaxiThruTap,
  });

  final HeyCabyColorTokens colors;
  final DriverColors driverColors;
  final HeyCabyTypography typo;
  final int scheduledCount;
  final bool scheduledCountLoading;
  final int todayRides;
  final int upcomingCount;
  final int taxiThruCount;
  final bool taxiThruCountLoading;
  final VoidCallback onScheduledTap;
  final VoidCallback onTodayTap;
  final VoidCallback onTaxiThruTap;

  @override
  Widget build(BuildContext context) {
    final todaySubtitle = DriverStrings.homeTodayRidesCount(todayRides);
    final postsSubtitle = taxiThruCountLoading
        ? DriverStrings.loading
        : taxiThruCount == 0
            ? DriverStrings.homeReturnTaxiPostsSubtitle
            : DriverStrings.homeAvailableCount(taxiThruCount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.md,
        DriverSpacing.md + 2,
        DriverSpacing.md,
        DriverSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: DriverSpacing.xs,
              bottom: DriverSpacing.md + 2,
            ),
            child: Text(
              DriverStrings.homeQuickActionsTitle,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _DriverHomeQuickActionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.event_rounded,
                  label: DriverStrings.scheduledRides,
                  subtitle: scheduledCountLoading
                      ? DriverStrings.loading
                      : DriverStrings.homePlannedScheduledCount(
                          scheduledCount,
                        ),
                  onTap: onScheduledTap,
                ),
              ),
              Expanded(
                child: _DriverHomeQuickActionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.local_taxi_rounded,
                  label: DriverStrings.today,
                  subtitle: todaySubtitle,
                  badgeCount: upcomingCount > 0 ? upcomingCount : null,
                  onTap: onTodayTap,
                ),
              ),
              Expanded(
                child: _DriverHomeQuickActionTile(
                  colors: colors,
                  typo: typo,
                  icon: Icons.campaign_rounded,
                  label: DriverStrings.homeOverviewRiderPosts,
                  subtitle: postsSubtitle,
                  badgeCount: taxiThruCount > 0 ? taxiThruCount : null,
                  onTap: onTaxiThruTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverHomeQuickActionTile extends StatelessWidget {
  const _DriverHomeQuickActionTile({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badgeCount,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: DriverSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.bgAlt,
                    ),
                    child: Icon(
                      icon,
                      color: colors.text,
                      size: 22,
                    ),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: -2,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.card, width: 1.5),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: typo.labelSmall.copyWith(
                            color: colors.onAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: typo.labelSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
