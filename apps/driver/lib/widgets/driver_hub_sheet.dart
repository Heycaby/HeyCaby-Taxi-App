import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_earnings_targets_notifier.dart';
import '../providers/driver_state_provider.dart';
import '../utils/driver_tariff_profile_slots.dart';
import '../utils/driver_hub_goal_progress.dart';
import 'driver_hub_saved_by_riders_section.dart';
import 'driver_hub_assets.dart';
import 'driver_hub_sign_tile.dart';
import 'driver_hub_step_sheets.dart';

/// Driver Hub — icon-first launcher (step sheets for detail). Signature toggle
/// lives on Home, not here.
class DriverHubSheet extends ConsumerWidget {
  const DriverHubSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);
    final earnings = ref.watch(driverEarningsProvider).valueOrNull;
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final activeRate = ref.watch(activeRateProfileProvider).valueOrNull;
    final billing = ref.watch(driverBillingStatusProvider).valueOrNull;
    final shift = ref.watch(driverShiftStatsProvider).valueOrNull;
    final targets = ref.watch(driverEarningsTargetsProvider).valueOrNull ?? {};
    final goalPeriod = ref.watch(driverHubEarningsPeriodProvider);

    final todayEuros = earnings?.formatEuros(earnings.todayEuros) ?? '€0.00';
    final moneyGoalPreview = earnings == null
        ? null
        : DriverHubTileGoalPreview.fromLiveData(
            targets: targets,
            preferredPeriod: goalPeriod,
            todayEuros: earnings.todayEuros,
            weekEuros: earnings.weekEuros,
            biweeklyEuros: earnings.biweeklyEuros,
            monthEuros: earnings.monthEuros,
            formatEuros: earnings.formatEuros,
          );
    final activeTariffSubtitle = activeRate == null
        ? DriverStrings.notSet
        : tariffProfileActiveHubSubtitle(
            profileName: activeRate.profileName,
            perKmRate: activeRate.perKmRate,
          );
    final plate = profile?.vehiclePlate?.trim();
    final ridesPaused = billing?['ride_requests_paused'] == true;
    final rides = shift?.shiftRidesToday ?? earnings?.todayRides ?? 0;

    final (statusLabel, statusColor) = switch (driver.appState) {
      DriverAppState.onlineAvailable ||
      DriverAppState.reviewingRequest ||
      DriverAppState.acceptingRide ||
      DriverAppState.assigned ||
      DriverAppState.arrived ||
      DriverAppState.inProgress ||
      DriverAppState.completingRide ||
      DriverAppState.completed =>
        (DriverStrings.online, colors.success),
      DriverAppState.onBreak => (DriverStrings.onBreak, colors.warning),
      _ => (DriverStrings.offline, colors.textSoft),
    };

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      tintColor: colors.card,
      child: DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DriverStrings.driverHub,
                        style: typo.headingMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: colors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: typo.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.hubTodayLabel,
                      style: typo.labelLarge.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          todayEuros,
                          style: typo.displaySmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colors.text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_taxi_rounded,
                                size: 18,
                                color: colors.textMid,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DriverStrings.hubRidesToday(rides),
                                style: typo.bodyMedium.copyWith(
                                  color: colors.textMid,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.12,
                  children: [
                    DriverHubSignTile(
                      colors: colors,
                      typography: typo,
                      icon: Icons.account_balance_wallet_rounded,
                      assetIconPath: DriverHubAssets.moneyWallet,
                      label: DriverStrings.hubTileMoney,
                      subtitle:
                          moneyGoalPreview?.subtitle ?? DriverStrings.hubTileSetGoal,
                      goalPreview: moneyGoalPreview,
                      onTap: () => showDriverHubMoneySheet(context, ref),
                    ),
                    DriverHubSignTile(
                      colors: colors,
                      typography: typo,
                      icon: Icons.speed_rounded,
                      assetIconPath: DriverHubAssets.setTariff,
                      label: DriverStrings.hubTileSetTariff,
                      subtitle: activeTariffSubtitle,
                      onInfoTap: () => showDriverHubTariffTooltip(context),
                      onTap: () => showDriverHubPricesSheet(context, ref),
                    ),
                    DriverHubSignTile(
                      colors: colors,
                      typography: typo,
                      icon: Icons.directions_car_rounded,
                      label: DriverStrings.hubTileTaxi,
                      subtitle: plate?.isNotEmpty == true
                          ? plate!
                          : DriverStrings.vehicle,
                      onTap: () => context.push('/driver/vehicle'),
                    ),
                    DriverHubSignTile(
                      colors: colors,
                      typography: typo,
                      icon: Icons.receipt_long_rounded,
                      label: DriverStrings.hubTileBalance,
                      badge: ridesPaused ? '!' : null,
                      badgeIsWarning: ridesPaused,
                      subtitle: ridesPaused
                          ? DriverStrings.platformBalanceRequestsPaused
                          : DriverStrings.platformBalanceCurrent,
                      tint: ridesPaused ? colors.warning : null,
                      onTap: () => context.push('/driver/billing'),
                    ),
                    DriverHubSignTile(
                      colors: colors,
                      typography: typo,
                      icon: Icons.shield_rounded,
                      label: DriverStrings.hubTileSafety,
                      tint: colors.error,
                      onTap: () => showDriverHubSafetySheet(context, ref),
                    ),
                    DriverHubSignTile(
                      colors: colors,
                      typography: typo,
                      icon: Icons.help_outline_rounded,
                      label: DriverStrings.hubTileHelp,
                      onTap: () => showDriverHubHelpSheet(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  DriverStrings.hubMoreTitle,
                  style: typo.titleSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HubMoreRow(
                  colors: colors,
                  typo: typo,
                  icon: Icons.tune_rounded,
                  label: DriverStrings.hubTileSettings,
                  onTap: () => context.push('/driver/preferences'),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DriverHubSavedByRidersSection(colors: colors, typo: typo),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HubMoreRow extends StatelessWidget {
  const _HubMoreRow({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textMid, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: typo.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSoft),
            ],
          ),
        ),
      ),
    );
  }
}
