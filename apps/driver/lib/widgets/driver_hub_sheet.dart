import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              // Removed redundant cards:
              // - Earnings (functionality in Live Stats)
              // - Set your tariff (move to Preferences)
              // - Set your driving preference (already in Preferences)
              // - Suggestion for the app (moved to Support section)
              
              // Grouped Quick Access - Settings & Support
              // Documents removed (available in sidebar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _HubQuickActionCard(
                    icon: Icons.settings_outlined,
                    title: DriverStrings.preferences,
                    subtitle: DriverStrings.preferencesSubtitle,
                    colors: colors,
                    typo: typo,
                    onTap: () => context.push('/driver/preferences'),
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
  Timer? _discountDebounce;
  Timer? _pickupDebounce;
  bool _didInitDiscount = false;
  bool _didInitPickup = false;
  double _returnDiscountPct = 0;
  double _pickupDistanceKm = 20;
  /// Avoid haptic spam: last snapped value we already ticked for.
  double? _lastDiscountSnapHaptic;
  double? _lastPickupSnapHaptic;

  @override
  void dispose() {
    _discountDebounce?.cancel();
    _pickupDebounce?.cancel();
    super.dispose();
  }

  String _chanceLabel(double pct) {
    if (pct <= 10) return 'low';
    if (pct <= 25) return 'medium';
    return 'high';
  }

  Color _chanceColor(HeyCabyColorTokens colors, double pct) {
    if (pct <= 10) return colors.error;
    if (pct <= 25) return colors.warning;
    return colors.success;
  }

  void _onDiscountChanged(double v, dynamic profile) {
    final snapped = ((v / 5).round() * 5.0).clamp(0, 40).toDouble();
    if (_lastDiscountSnapHaptic != snapped) {
      _lastDiscountSnapHaptic = snapped;
      HapticService.selectionClick();
    }
    setState(() => _returnDiscountPct = snapped);
    _discountDebounce?.cancel();
    _discountDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (profile == null) return;
      final ok = await ref.read(driverDataServiceProvider).updateReturnDiscountPct(
            rateProfileId: profile.id,
            returnDiscountPct: _returnDiscountPct,
          );
      if (!mounted) return;
      if (ok) {
        HapticService.mediumTap();
        ref.invalidate(driverRateProfilesProvider);
        ref.invalidate(activeRateProfileProvider);
        ref.invalidate(driverProfileProvider);
      }
    });
  }

  void _onPickupDistanceChanged(double v) {
    final snapped = ((v / 5).round() * 5.0).clamp(5, 50).toDouble();
    if (_lastPickupSnapHaptic != snapped) {
      _lastPickupSnapHaptic = snapped;
      HapticService.selectionClick();
    }
    setState(() => _pickupDistanceKm = snapped);
    _pickupDebounce?.cancel();
    _pickupDebounce = Timer(const Duration(milliseconds: 700), () async {
      final driverId = await ref.read(driverIdProvider.future);
      if (driverId == null) return;
      final ok = await ref.read(driverDataServiceProvider).updateDriverPrefs(
            driverId,
            pickupDistanceMaxKm: _pickupDistanceKm,
          );
      if (!mounted) return;
      if (ok) {
        HapticService.mediumTap();
        ref.invalidate(driverProfileProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final earnings = ref.watch(driverEarningsProvider).valueOrNull;
    final shift = ref.watch(driverShiftStatsProvider).valueOrNull;
    final zones = ref.watch(zoneDemandProvider).valueOrNull ?? const [];
    final activeRate = ref.watch(activeRateProfileProvider).valueOrNull;
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final todayEuros = earnings?.todayEuros ?? 0.0;
    final rides = shift?.shiftRidesToday ?? earnings?.todayRides ?? 0;
    final hasHighDemand = zones.any((z) => z.waitingPassengers >= 20);
    final pct = _returnDiscountPct.clamp(0, 40).toDouble();
    final pickupKm = _pickupDistanceKm.clamp(5, 50).toDouble();

    if (activeRate != null && !_didInitDiscount) {
      _didInitDiscount = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final fromServer =
            ((activeRate.returnDiscountPct ?? 0).toDouble()).clamp(0, 40).toDouble();
        setState(() {
          _returnDiscountPct = fromServer;
          _lastDiscountSnapHaptic = fromServer;
        });
      });
    }
    if (profile != null && !_didInitPickup) {
      _didInitPickup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final fromServer =
            ((profile.pickupDistanceMaxKm ?? 20).toDouble()).clamp(5, 50).toDouble();
        setState(() {
          _pickupDistanceKm = fromServer;
          _lastPickupSnapHaptic = fromServer;
        });
      });
    }

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
                      hasHighDemand ? Icons.local_fire_department : Icons.timelapse,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.card.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border.withValues(alpha: 0.75)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return discount',
                          style: typo.labelSmall.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: typo.titleSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.card.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border.withValues(alpha: 0.75)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DriverStrings.pickupDistance,
                          style: typo.labelSmall.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pickupKm.toStringAsFixed(0)} km',
                          style: typo.titleSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: colors.border.withValues(alpha: 0.75)),
            const SizedBox(height: 10),
            Slider(
              min: 0,
              max: 40,
              divisions: 8,
              value: pct,
              activeColor: colors.accent,
              inactiveColor: colors.border,
              onChanged: activeRate == null ? null : (v) => _onDiscountChanged(v, activeRate),
            ),
            const SizedBox(height: 4),
            Slider(
              min: 5,
              max: 50,
              divisions: 9,
              value: pickupKm,
              activeColor: colors.accent,
              inactiveColor: colors.border,
              onChanged: profile == null ? null : _onPickupDistanceChanged,
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _chanceColor(colors, pct).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _chanceColor(colors, pct).withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    'Match chance: ${_chanceLabel(pct)}',
                    style: typo.bodySmall.copyWith(
                      color: _chanceColor(colors, pct),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/driver/return-trips'),
                  child: Text(DriverStrings.openReturnRides),
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
