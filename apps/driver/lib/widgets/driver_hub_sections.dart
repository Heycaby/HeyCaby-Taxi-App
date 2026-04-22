import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';

/// Section 1 — Goals: hero earned amount, period chips (strong selected), set goal CTA.
class DriverHubEarningsTargetSection extends ConsumerWidget {
  const DriverHubEarningsTargetSection({
    super.key,
    required this.colors,
    required this.typo,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(driverEarningsProvider);
    final targetsAsync = ref.watch(driverEarningsTargetsProvider);
    final earnings = earningsAsync.valueOrNull;
    final targets = targetsAsync.valueOrNull ?? {};
    final todayEuros = earnings?.todayEuros ?? 0;
    final period = ref.watch(_earningsTargetPeriodProvider);
    final targetAmount = period == 'daily'
        ? (targets['daily'] ?? 0)
        : (targets['weekly'] ?? 0);
    final displayedEarned = period == 'daily' ? todayEuros : (earnings?.weekEuros ?? 0);
    final remaining = targetAmount > 0 ? (targetAmount - displayedEarned).clamp(0.0, double.infinity) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.goalsSectionTitle,
            style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            DriverStrings.goalsSectionHelper,
            style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PeriodChip(
                label: DriverStrings.daily,
                selected: period == 'daily',
                colors: colors,
                typo: typo,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(_earningsTargetPeriodProvider.notifier).state = 'daily';
                },
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: DriverStrings.weekly,
                selected: period == 'weekly',
                colors: colors,
                typo: typo,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(_earningsTargetPeriodProvider.notifier).state = 'weekly';
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '€${displayedEarned.toStringAsFixed(2)}',
                style: typo.headingLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DriverStrings.earnedLabel,
                style: typo.bodyMedium.copyWith(color: colors.textSoft, fontSize: 15),
              ),
            ],
          ),
          if (targetAmount > 0) ...[
            const SizedBox(height: 6),
            Text(
              DriverStrings.remainingToGoal(remaining.toStringAsFixed(0)),
              style: typo.bodyMedium.copyWith(color: colors.textMid, fontSize: 15),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _showSetTargetSheet(context, ref, period, targetAmount, colors, typo),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              child: const Text(DriverStrings.setGoalButton),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetTargetSheet(
    BuildContext context,
    WidgetRef ref,
    String period,
    double current,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
  ) {
    final controller = TextEditingController(text: current > 0 ? current.toInt().toString() : '');
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${DriverStrings.earningsTarget} (${period == 'daily' ? DriverStrings.dailyLong : DriverStrings.weeklyLong})',
              style: typo.titleMedium.copyWith(color: colors.text),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 10,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '€',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(controller.text.replaceAll(',', '.'));
                  if (amount != null && amount > 0) {
                    final id = await ref.read(driverIdProvider.future);
                    if (id != null) {
                      await ref.read(driverDataServiceProvider).upsertEarningsTarget(id, period, amount);
                      ref.invalidate(driverEarningsTargetsProvider);
                    }
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                child: Text(
                  DriverStrings.save,
                  style: typo.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _earningsTargetPeriodProvider = StateProvider<String>((_) => 'daily');

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: colors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Section 2 — Jouw tarieven: chip row (strong selected), 4 metric pills, manage link.
class DriverHubRatesSection extends ConsumerWidget {
  const DriverHubRatesSection({super.key, required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(driverRateProfilesProvider).valueOrNull ?? [];
    final activeProfile = ref.watch(activeRateProfileProvider).valueOrNull;
    final driverId = ref.watch(driverIdProvider).valueOrNull;
    final isLoading = ref.watch(driverRateProfilesProvider).isLoading;

    Future<void> onChipTap(String profileId) async {
      if (driverId == null) return;
      final ok = await ref.read(driverDataServiceProvider).switchRateProfile(driverId, profileId);
      if (ok) {
        ref.invalidate(driverRateProfilesProvider);
        ref.invalidate(activeRateProfileProvider);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.ratesSectionTitle,
            style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            DriverStrings.ratesSectionHelper,
            style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                ),
              ),
            )
          else if (profiles.isEmpty)
            GestureDetector(
              onTap: () async {
                if (driverId == null) return;
                await ref.read(driverDataServiceProvider).createFirstRateProfile(driverId);
                if (context.mounted) {
                  ref.invalidate(driverRateProfilesProvider);
                  ref.invalidate(activeRateProfileProvider);
                }
              },
              child: Text(
                DriverStrings.setUpRates,
                style: typo.bodyMedium.copyWith(color: colors.accent, fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in profiles)
                  _HubRateChip(
                    label: p.profileName,
                    selected: p.id == activeProfile?.id,
                    colors: colors,
                    typo: typo,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onChipTap(p.id);
                    },
                  ),
              ],
            ),
            if (activeProfile != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _RatePill(
                      label: DriverStrings.rateStart,
                      value: '€${activeProfile.baseFare.toStringAsFixed(2)}',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RatePill(
                      label: DriverStrings.ratePerKm,
                      value: '€${activeProfile.perKmRate.toStringAsFixed(2)}',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RatePill(
                      label: DriverStrings.ratePerMin,
                      value: '€${activeProfile.perMinRate.toStringAsFixed(2)}',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RatePill(
                      label: DriverStrings.rateWaiting,
                      value: '€${activeProfile.waitingRate.toStringAsFixed(2)}/min',
                      colors: colors,
                      typo: typo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  // TODO: navigate to full rate management
                },
                child: Text(
                  DriverStrings.manageRatesLink,
                  style: typo.bodySmall.copyWith(color: colors.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HubRateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _HubRateChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: colors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RatePill extends StatelessWidget {
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _RatePill({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.labelSmall.copyWith(color: colors.textSoft, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Section 3 — Veiligheid: 112 prominent red CTA, share/audio with clear disabled state.
class DriverHubSafetySection extends ConsumerWidget {
  const DriverHubSafetySection({super.key, required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverStateProvider);
    final driverId = ref.watch(driverIdProvider).valueOrNull;
    final isOnRide = driver.appState == DriverAppState.assigned ||
        driver.appState == DriverAppState.arrived ||
        driver.appState == DriverAppState.inProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.safetySectionTitle,
            style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                if (driverId != null && driverId.isNotEmpty) {
                  try {
                    await ref.read(driverDataServiceProvider).insertSafetyEvent(
                      driverId,
                      'emergency_call',
                      rideRequestId: driver.activeRideId,
                    );
                  } catch (e) {
                    if (kDebugMode) debugPrint('Safety event error: $e');
                  }
                }
                if (context.mounted) {
                  await launchUrl(Uri.parse('tel:112'));
                }
              },
              icon: const Icon(AppIcons.emergency, size: 22),
              label: const Text(DriverStrings.call112),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.card,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SafetyRow(
            icon: AppIcons.share,
            iconColor: isOnRide ? colors.textMid : colors.textSoft,
            title: DriverStrings.shareTripDetails,
            titleColor: colors.text,
            subtitle: isOnRide ? DriverStrings.shareTripSubtitleActive : DriverStrings.shareTripSubtitleInactive,
            colors: colors,
            typo: typo,
            active: isOnRide,
            onTap: isOnRide && driver.activeRideId != null
                ? () async {
                    final url = await ref.read(driverDataServiceProvider).getOrCreateRideShareUrl(driver.activeRideId!);
                    if (url != null && context.mounted) {
                      await Share.share(url);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          _SafetyRow(
            icon: AppIcons.audio,
            iconColor: isOnRide ? colors.textMid : colors.textSoft,
            title: DriverStrings.audioRecording,
            titleColor: colors.text,
            subtitle: isOnRide ? DriverStrings.audioRecordingSubtitleActive : DriverStrings.audioRecordingSubtitleInactive,
            colors: colors,
            typo: typo,
            active: isOnRide,
            onTap: isOnRide && driverId != null
                ? () async {
                    await ref.read(driverDataServiceProvider).insertSafetyEvent(
                      driverId,
                      'audio_recording',
                      rideRequestId: driver.activeRideId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(DriverStrings.recordingInProgress)),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool active;
  final VoidCallback? onTap;

  const _SafetyRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? colors.card : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: active ? 1 : 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: typo.bodyMedium.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          decoration: active ? null : TextDecoration.none,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: typo.bodySmall.copyWith(
                          color: active ? colors.textSoft : colors.textSoft,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active && onTap != null)
                  Icon(AppIcons.chevronRight, color: colors.textSoft, size: 20)
                else
                  Text(
                    '—',
                    style: typo.bodySmall.copyWith(color: colors.border, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section 4 — Hulp: Chat met support first, Help artikelen, tickets secondary.
class DriverHubHelpSection extends ConsumerWidget {
  const DriverHubHelpSection({super.key, required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(driverRecentTicketsProvider);
    final tickets = ticketsAsync.valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.helpSectionTitle,
            style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _openNewTicket(context, ref),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(AppIcons.chat, color: colors.accent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.chatWithSupport,
                            style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            DriverStrings.chatWithSupportHelper,
                            style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevronRight, color: colors.textSoft, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _HelpTile(
            icon: AppIcons.article,
            title: DriverStrings.helpArticles,
            colors: colors,
            typo: typo,
            onTap: () => _openHelpArticles(context, ref),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(
            DriverStrings.recentTickets,
            style: typo.labelSmall.copyWith(color: colors.textSoft, fontSize: 12),
          ),
              GestureDetector(
                onTap: () => context.push('/driver/support'),
                child: Text(
                  DriverStrings.seeAllTickets,
                  style: typo.bodySmall.copyWith(color: colors.accent, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...tickets.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => context.push('/driver/support'),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.zoneName ?? 'Rit',
                                style: typo.bodyMedium.copyWith(color: colors.text, fontSize: 14),
                              ),
                              Text(
                                t.createdAt != null
                                    ? '${t.createdAt!.day}/${t.createdAt!.month}/${t.createdAt!.year} · ${t.statusLabel}'
                                    : t.statusLabel,
                                style: typo.bodySmall.copyWith(
                                  color: t.status == 'resolved' ? colors.success : t.hasDriverReplied ? colors.warning : colors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(AppIcons.chevronRight, color: colors.textSoft, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  void _openNewTicket(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(driverStateProvider).userId;
    if (userId == null) return;
    try {
      await ref.read(driverDataServiceProvider).createTicket(userId);
      ref.invalidate(driverRecentTicketsProvider);
      if (context.mounted) context.push('/driver/support');
    } catch (e) {
      if (kDebugMode) debugPrint('Create ticket error: $e');
    }
  }

  void _openHelpArticles(BuildContext context, WidgetRef ref) async {
    final url = await ref.read(driverDataServiceProvider).getDriverHelpUrl();
    if (context.mounted) context.push('/driver/help-articles', extra: url);
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: colors.textMid, size: 22),
      title: Text(title, style: typo.bodyMedium.copyWith(color: colors.text)),
      trailing: Icon(AppIcons.chevronRight, color: colors.textSoft, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Bottom — Pro tools compact card: Power Mode + Union Mode.
class DriverHubPowerUnionRows extends StatelessWidget {
  const DriverHubPowerUnionRows({super.key, required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            DriverStrings.proToolsTitle,
            style: typo.labelSmall.copyWith(color: colors.textSoft, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              _HubFeatureRow(
                icon: AppIcons.bolt,
                iconColor: colors.accent,
                title: DriverStrings.driverPowerMode,
                subtitle: DriverStrings.driverPowerModeSubtitle,
                colors: colors,
                typo: typo,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/driver/power-mode');
                },
              ),
              Divider(height: 1, color: colors.border),
              _HubFeatureRow(
                icon: AppIcons.groups,
                iconColor: colors.textMid,
                title: DriverStrings.driverUnionMode,
                subtitle: DriverStrings.driverUnionModeSubtitle,
                colors: colors,
                typo: typo,
                onTap: () => context.push('/driver/union-mode'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubFeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _HubFeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, color: colors.textSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
