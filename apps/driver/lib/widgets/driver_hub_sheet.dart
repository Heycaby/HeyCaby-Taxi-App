import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import 'driver_hub_saved_by_riders_section.dart';
import 'driver_hub_sections.dart';

/// Driver Hub bottom sheet — 85% height, drag handle, 4 sections + Pro tools.
class DriverHubSheet extends ConsumerWidget {
  const DriverHubSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);

    String statusLabel;
    Color statusColor;
    switch (driver.appState) {
      case DriverAppState.onlineAvailable:
      case DriverAppState.reviewingRequest:
      case DriverAppState.acceptingRide:
      case DriverAppState.assigned:
      case DriverAppState.arrived:
      case DriverAppState.inProgress:
      case DriverAppState.completingRide:
      case DriverAppState.completed:
        statusLabel = DriverStrings.online;
        statusColor = colors.success;
        break;
      case DriverAppState.onBreak:
        statusLabel = DriverStrings.onBreak;
        statusColor = colors.warning;
        break;
      default:
        statusLabel = DriverStrings.offline;
        statusColor = colors.textSoft;
    }

    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      tintColor: colors.card,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DriverStrings.driverHub,
                                  style: typo.headingMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: colors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DriverStrings.driverHubSubtitle,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: typo.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: _HubLiveStrip(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubRatesSection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubSavedByRidersSection(
                    colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      _HubQuickActionCard(
                        icon: Icons.tune_rounded,
                        title: DriverStrings.driverHubBusinessControls,
                        subtitle: DriverStrings.driverHubBusinessControlsHint,
                        colors: colors,
                        typo: typo,
                        onTap: () => context.push('/driver/preferences'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _HubQuickActionCard(
                              icon: Icons.directions_car_rounded,
                              title: DriverStrings.vehicle,
                              subtitle:
                                  DriverStrings.vehicleVerifiedTaxiEnglish,
                              colors: colors,
                              typo: typo,
                              onTap: () => context.push('/driver/vehicle'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HubQuickActionCard(
                              icon: Icons.receipt_long_rounded,
                              title: DriverStrings.platformBalanceTitle,
                              subtitle: DriverStrings.platformBalanceCurrent,
                              colors: colors,
                              typo: typo,
                              onTap: () => context.push('/driver/billing'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubSafetySection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverToBoxAdapter(
                child: DriverHubHelpSection(colors: colors, typo: typo),
              ),
              SliverToBoxAdapter(
                child: _Divider(colors: colors),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox(height: MediaQuery.of(context).padding.bottom),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final HeyCabyColorTokens colors;

  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: colors.border);
  }
}

class _HubLiveStrip extends ConsumerStatefulWidget {
  const _HubLiveStrip({required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  ConsumerState<_HubLiveStrip> createState() => _HubLiveStripState();
}

class _HubLiveStripState extends ConsumerState<_HubLiveStrip> {
  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final earnings = ref.watch(driverEarningsProvider).valueOrNull;
    final shift = ref.watch(driverShiftStatsProvider).valueOrNull;
    final zones = ref.watch(zoneDemandProvider).valueOrNull ?? const [];
    final todayEuros = earnings?.todayEuros ?? 0.0;
    final rides = shift?.shiftRidesToday ?? earnings?.todayRides ?? 0;
    final hasHighDemand = zones.any((z) => z.waitingPassengers >= 20);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '€${todayEuros.toStringAsFixed(0)} today • $rides rides',
                    style: typo.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      hasHighDemand
                          ? Icons.local_fire_department
                          : Icons.timelapse,
                      size: 16,
                      color: hasHighDemand ? colors.warning : colors.textSoft,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasHighDemand ? 'High demand' : 'Normal demand',
                      style: typo.labelSmall.copyWith(
                        color: hasHighDemand ? colors.warning : colors.textSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DriverStrings.driverHubReturnModeHint,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/driver/return-trips'),
                  child: const Text(DriverStrings.openReturnRides),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HubQuickActionCard extends StatelessWidget {
  const _HubQuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textMid, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typo.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
