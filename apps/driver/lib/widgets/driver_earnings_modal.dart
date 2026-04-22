import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

/// Status color: green (online), amber (on break), red (offline).
Color statusColor(DriverStatusKind kind, HeyCabyColorTokens colors) {
  switch (kind) {
    case DriverStatusKind.online:
      return colors.success;
    case DriverStatusKind.onBreak:
      return colors.warning;
    case DriverStatusKind.offline:
      return colors.error;
  }
}

enum DriverStatusKind { online, onBreak, offline }

/// Earnings pill on the map. Design: today · zone/status, tappable.
/// When online/on break, shows "Online · since 14:32" or "On break · since 15:10" from [statusTime].
class DriverEarningsPill extends StatelessWidget {
  const DriverEarningsPill({
    super.key,
    required this.todayEarnings,
    required this.zoneName,
    required this.statusKind,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.statusTime,
  });

  final String todayEarnings;
  final String zoneName;
  final DriverStatusKind statusKind;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  /// When set and status is online or on break, pill shows "Online · since HH:mm" / "On break · since HH:mm".
  final DateTime? statusTime;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(statusKind, colors);
    String rightText = zoneName;
    if (statusTime != null &&
        (statusKind == DriverStatusKind.online || statusKind == DriverStatusKind.onBreak)) {
      final hm = '${statusTime!.hour.toString().padLeft(2, '0')}:${statusTime!.minute.toString().padLeft(2, '0')}';
      rightText = statusKind == DriverStatusKind.online
          ? '${DriverStrings.onlineSince} $hm'
          : '${DriverStrings.onBreakSince} $hm';
    }
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      shadowColor: colors.text.withValues(alpha: 0.26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                todayEarnings,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 14,
                  color: colors.border,
                ),
              ),
              Text(
                rightText,
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Control-center modal: earnings, zone, status, rate profiles. V3: wired to Supabase.
class DriverEarningsModal extends ConsumerStatefulWidget {
  const DriverEarningsModal({
    super.key,
    required this.todayEarnings,
    required this.zoneName,
    required this.statusKind,
    required this.colors,
    required this.typo,
    required this.onDismiss,
    required this.onTakeBreak,
    required this.onEndShift,
    required this.onResume,
  });

  final String todayEarnings;
  final String zoneName;
  final DriverStatusKind statusKind;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onDismiss;
  final VoidCallback onTakeBreak;
  final VoidCallback onEndShift;
  final VoidCallback onResume;

  @override
  ConsumerState<DriverEarningsModal> createState() => _DriverEarningsModalState();
}

class _DriverEarningsModalState extends ConsumerState<DriverEarningsModal> {
  bool _amountVisible = true;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final displayAmount = _amountVisible ? widget.todayEarnings : '••••••';
    final statusCol = statusColor(widget.statusKind, colors);
    final statusLabel = widget.statusKind == DriverStatusKind.online
        ? DriverStrings.online
        : widget.statusKind == DriverStatusKind.onBreak
            ? DriverStrings.onBreak
            : DriverStrings.offline;
    final profilesAsync = ref.watch(driverRateProfilesProvider);
    final activeAsync = ref.watch(activeRateProfileProvider);
    final driverIdAsync = ref.watch(driverIdProvider);
    final statsAsync = ref.watch(driverShiftStatsProvider);
    final profiles = profilesAsync.valueOrNull ?? [];
    final activeProfile = activeAsync.valueOrNull;
    final driverId = driverIdAsync.valueOrNull;
    final stats = statsAsync.valueOrNull;
    final continuousMins = stats?.continuousDrivingMinutes ?? 0;
    final showBreakBanner = continuousMins > 255;
    final breakBannerRed = continuousMins >= 270;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            _amountVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: colors.textSoft,
                          ),
                          onPressed: () =>
                              setState(() => _amountVisible = !_amountVisible),
                        ),
                        Text(
                          DriverStrings.today,
                          style: typo.bodySmall.copyWith(color: colors.textSoft),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    Text(
                      displayAmount,
                      style: typo.headingLarge.copyWith(
                        color: colors.text,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusCol,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: typo.bodyMedium.copyWith(
                            color: statusCol,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.zoneName,
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 12),
                    RateProfileSection(
                      colors: colors,
                      typo: typo,
                      profiles: profiles,
                      activeProfile: activeProfile,
                      driverId: driverId,
                      isLoading: profilesAsync.isLoading,
                      onProfileSelected: () {
                        ref.invalidate(driverRateProfilesProvider);
                        ref.invalidate(activeRateProfileProvider);
                      },
                      onCreateFirst: () async {
                        if (driverId == null) return;
                        await ref.read(driverDataServiceProvider).createFirstRateProfile(driverId);
                        if (context.mounted) {
                          ref.invalidate(driverRateProfilesProvider);
                          ref.invalidate(activeRateProfileProvider);
                        }
                      },
                    ),
                    if (showBreakBanner) ...[
                      const SizedBox(height: 12),
                      _BreakBanner(
                        colors: colors,
                        typo: typo,
                        isRed: breakBannerRed,
                        minutesLeft: breakBannerRed ? 0 : 270 - continuousMins,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        widget.onDismiss();
                        context.go('/driver/work');
                      },
                      icon: Icon(Icons.receipt_long, size: 18, color: colors.accent),
                      label: Text(
                        DriverStrings.viewDetails,
                        style: typo.bodyMedium.copyWith(color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: -0.3, end: 0, curve: Curves.easeOut).fadeIn(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable rate profile chips + rate line; used in earnings modal and Driver Hub.
class RateProfileSection extends ConsumerWidget {
  const RateProfileSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.profiles,
    required this.activeProfile,
    required this.driverId,
    required this.isLoading,
    required this.onProfileSelected,
    required this.onCreateFirst,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final List<DriverRateProfile> profiles;
  final DriverRateProfile? activeProfile;
  final String? driverId;
  final bool isLoading;
  final VoidCallback onProfileSelected;
  final VoidCallback onCreateFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> onChipTap(String profileId) async {
      if (driverId == null) return;
      final ok = await ref.read(driverDataServiceProvider).switchRateProfile(driverId!, profileId);
      if (ok) onProfileSelected();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DriverStrings.activeRates,
              style: typo.labelSmall.copyWith(color: colors.textSoft),
            ),
            FilledButton.icon(
              onPressed: () {
                // Until a dedicated rates screen exists, send drivers to Work tab.
                context.go('/driver/work');
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent.withValues(alpha: 0.14),
                foregroundColor: colors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                DriverStrings.manageRates,
                style: typo.bodySmall.copyWith(color: colors.accent, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 20,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
              ),
            ),
          )
        else if (profiles.isEmpty)
          GestureDetector(
            onTap: onCreateFirst,
            child: Text(
              DriverStrings.setUpRates,
              style: typo.bodySmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in profiles)
                _RateChip(
                  label: p.profileName,
                  selected: p.id == activeProfile?.id,
                  colors: colors,
                  typo: typo,
                  onTap: () => onChipTap(p.id),
                ),
            ],
          ),
        if (activeProfile != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RateMetricPill(
                  label: DriverStrings.rateStart,
                  value: '€${activeProfile!.baseFare.toStringAsFixed(2)}',
                  colors: colors,
                  typo: typo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RateMetricPill(
                  label: DriverStrings.ratePerKm,
                  value: '€${activeProfile!.perKmRate.toStringAsFixed(2)}',
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
                child: _RateMetricPill(
                  label: DriverStrings.ratePerMin,
                  value: '€${activeProfile!.perMinRate.toStringAsFixed(2)}',
                  colors: colors,
                  typo: typo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RateMetricPill(
                  label: DriverStrings.rateWaiting,
                  value: '€${activeProfile!.waitingRate.toStringAsFixed(2)}/min',
                  colors: colors,
                  typo: typo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activeProfile!.ratesLine,
            style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _RateMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _RateMetricPill({
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
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
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
            style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BreakBanner extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool isRed;
  final int minutesLeft;

  const _BreakBanner({
    required this.colors,
    required this.typo,
    required this.isRed,
    required this.minutesLeft,
  });

  @override
  Widget build(BuildContext context) {
    final bg = (isRed ? colors.error : colors.warning).withValues(alpha: 0.15);
    final text = isRed
        ? DriverStrings.breakRequired
        : DriverStrings.breakRecommended.replaceFirst('X', '$minutesLeft');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: isRed ? colors.error : colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: typo.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onTap;

  const _RateChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.accent),
        ),
        child: Text(
          label,
          style: typo.bodySmall.copyWith(
            color: selected ? colors.text : colors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
