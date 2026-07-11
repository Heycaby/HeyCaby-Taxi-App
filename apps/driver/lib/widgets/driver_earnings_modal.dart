import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_earnings_modal_parts.dart';
import 'driver_ride_premium_style.dart';

/// Light modal chrome — neutral surface, green used only as accent.
abstract final class _EarningsModalStyle {
  _EarningsModalStyle._();

  static BoxDecoration cardShell(DriverColors colors) =>
      DriverRidePremiumStyle.frostedFill(
        colors,
        borderRadius: DriverRadius.xlAll,
        tint: colors.card,
        tintOpacity: 0.78,
      );

  static BoxDecoration insetPanel(DriverColors colors) => BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: DriverRadius.mdAll,
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      );
}

class _EarningsModalHandle extends StatelessWidget {
  const _EarningsModalHandle({required this.colors});

  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(
          top: DriverSpacing.sm,
          bottom: DriverSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DriverRadius.pill),
          color: colors.border.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _EarningsModalSoftIcon extends StatelessWidget {
  const _EarningsModalSoftIcon({
    required this.icon,
    required this.colors,
  });

  final IconData icon;
  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.backgroundAlt,
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Icon(icon, color: colors.primary, size: 22),
    );
  }
}

/// Live earnings + active tariff command center on the map.
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
  ConsumerState<DriverEarningsModal> createState() =>
      _DriverEarningsModalState();
}

class _DriverEarningsModalState extends ConsumerState<DriverEarningsModal> {
  bool _amountVisible = true;

  @override
  Widget build(BuildContext context) {
    final driverColors = DriverColors.fromTheme(widget.colors);
    final driverTypo = DriverTypography.fromTheme(widget.typo);
    final displayAmount = _amountVisible ? widget.todayEarnings : '••••••';
    final activeAsync = ref.watch(activeRateProfileProvider);
    final activeProfile = activeAsync.valueOrNull;
    final profilesAsync = ref.watch(driverRateProfilesProvider);
    final profiles = profilesAsync.valueOrNull ?? [];
    final driverId = ref.watch(driverIdProvider).valueOrNull;
    final stats = ref.watch(driverShiftStatsProvider).valueOrNull;
    final ridesToday = stats?.shiftRidesToday ?? 0;
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: driverColors.text.withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            top: topInset + 28,
            left: DriverSpacing.screenEdge,
            right: DriverSpacing.screenEdge,
            child: GestureDetector(
              onTap: () {},
              child: _EarningsModalCard(
                driverColors: driverColors,
                driverTypo: driverTypo,
                displayAmount: displayAmount,
                amountVisible: _amountVisible,
                statusKind: widget.statusKind,
                zoneName: widget.zoneName,
                ridesToday: ridesToday,
                activeProfile: activeProfile,
                profiles: profiles,
                driverId: driverId,
                onToggleVisibility: () =>
                    setState(() => _amountVisible = !_amountVisible),
                onDismiss: widget.onDismiss,
                onTariffTap: () => _showTariffDetails(
                  context,
                  activeProfile,
                  widget.colors,
                  widget.typo,
                ),
                onSwitchProfile: (profileId) async {
                  if (driverId == null) return;
                  final ok = await ref
                      .read(driverDataServiceProvider)
                      .switchRateProfile(driverId, profileId);
                  if (ok) {
                    ref.invalidate(driverRateProfilesProvider);
                    ref.invalidate(activeRateProfileProvider);
                  }
                },
              ).driverSuccessPop(),
            ),
          ),
        ],
      ),
    );
  }

  void _showTariffDetails(
    BuildContext context,
    DriverRateProfile? profile,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
  ) {
    final profiles = ref.read(driverRateProfilesProvider).valueOrNull ?? [];
    final driverId = ref.read(driverIdProvider).valueOrNull;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TariffDetailsSheet(
        profile: profile,
        profiles: profiles,
        driverId: driverId,
        colors: colors,
        typo: typo,
        onEdit: () {
          Navigator.pop(context);
          widget.onDismiss();
          context.push('/driver/tariffs');
        },
        onSwitchProfile: (profileId) async {
          if (driverId == null) return;
          final ok = await ref
              .read(driverDataServiceProvider)
              .switchRateProfile(driverId, profileId);
          if (ok) {
            ref.invalidate(driverRateProfilesProvider);
            ref.invalidate(activeRateProfileProvider);
            if (context.mounted) Navigator.pop(context);
          }
        },
      ),
    );
  }
}

class _EarningsModalCard extends StatelessWidget {
  const _EarningsModalCard({
    required this.driverColors,
    required this.driverTypo,
    required this.displayAmount,
    required this.amountVisible,
    required this.statusKind,
    required this.zoneName,
    required this.ridesToday,
    required this.activeProfile,
    required this.profiles,
    required this.driverId,
    required this.onToggleVisibility,
    required this.onDismiss,
    required this.onTariffTap,
    required this.onSwitchProfile,
  });

  final DriverColors driverColors;
  final DriverTypography driverTypo;
  final String displayAmount;
  final bool amountVisible;
  final DriverStatusKind statusKind;
  final String zoneName;
  final int ridesToday;
  final DriverRateProfile? activeProfile;
  final List<DriverRateProfile> profiles;
  final String? driverId;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDismiss;
  final VoidCallback onTariffTap;
  final Future<void> Function(String profileId) onSwitchProfile;

  @override
  Widget build(BuildContext context) {
    final tariffName =
        activeProfile?.profileName ?? DriverStrings.standardTariff;
    final tariffSummary = _tariffSummary(activeProfile);

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: _EarningsModalStyle.cardShell(driverColors),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EarningsModalHandle(colors: driverColors),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.lg,
              0,
              DriverSpacing.md,
              DriverSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: driverColors.primary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DriverStrings.today.toUpperCase(),
                        style: driverTypo.labelSmall.copyWith(
                          color: driverColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DriverStrings.shiftStatEarnings,
                        style: driverTypo.bodySmall.copyWith(
                          color: driverColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _EarningsModalIconButton(
                  icon: amountVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  colors: driverColors,
                  onTap: onToggleVisibility,
                ),
                const SizedBox(width: DriverSpacing.xs),
                _EarningsModalIconButton(
                  icon: Icons.close_rounded,
                  colors: driverColors,
                  onTap: onDismiss,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DriverSpacing.lg),
            child: GestureDetector(
              onTap: onToggleVisibility,
              behavior: HitTestBehavior.opaque,
              child: Align(
                alignment: Alignment.centerLeft,
                child: DriverAnimatedEarnings(
                  value: displayAmount,
                  style: driverTypo.displayMedium.copyWith(
                    color: amountVisible
                        ? driverColors.text
                        : driverColors.textMuted,
                    fontWeight: FontWeight.w900,
                    fontSize: 48,
                    height: 1,
                    letterSpacing: amountVisible ? 0 : 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DriverSpacing.lg),
            child: Wrap(
              spacing: DriverSpacing.sm,
              runSpacing: DriverSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _EarningsModalStatusBadge(
                  statusKind: statusKind,
                  colors: driverColors,
                  typography: driverTypo,
                ),
                if (zoneName.trim().isNotEmpty && zoneName != '—')
                  _EarningsModalZoneChip(
                    zoneName: zoneName,
                    colors: driverColors,
                    typography: driverTypo,
                  ),
                _EarningsModalStatPill(
                  icon: Icons.local_taxi_rounded,
                  label: DriverStrings.homeTodayRidesCount(ridesToday),
                  colors: driverColors,
                  typography: driverTypo,
                ),
              ],
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.lg,
              0,
              DriverSpacing.lg,
              DriverSpacing.lg,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: DriverRadius.mdAll,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTariffTap,
                borderRadius: DriverRadius.mdAll,
                child: Ink(
                  decoration: _EarningsModalStyle.insetPanel(driverColors),
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.md),
                    child: Row(
                      children: [
                        _EarningsModalSoftIcon(
                          icon: Icons.payments_outlined,
                          colors: driverColors,
                        ),
                        const SizedBox(width: DriverSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DriverStrings.activeTariff,
                                style: driverTypo.labelSmall.copyWith(
                                  color: driverColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tariffName,
                                style: driverTypo.titleSmall.copyWith(
                                  color: driverColors.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (tariffSummary != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  tariffSummary,
                                  style: driverTypo.labelMedium.copyWith(
                                    color: driverColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: driverColors.textMuted,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (profiles.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DriverSpacing.lg,
                0,
                DriverSpacing.lg,
                DriverSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverStrings.pricingSwitchTariff,
                    style: driverTypo.labelSmall.copyWith(
                      color: driverColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: profiles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: DriverSpacing.sm),
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final isActive = profile.id == activeProfile?.id;
                        return _TariffProfileChip(
                          label: profile.profileName,
                          isActive: isActive,
                          colors: driverColors,
                          typography: driverTypo,
                          onTap: isActive
                              ? null
                              : () => onSwitchProfile(profile.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 4),
        ],
      ),
    );
  }

  String? _tariffSummary(DriverRateProfile? profile) {
    if (profile == null) return null;
    final base = profile.baseFare.toStringAsFixed(2);
    final km = profile.perKmRate.toStringAsFixed(2);
    return '€$base · €$km/km';
  }
}

class _EarningsModalIconButton extends StatelessWidget {
  const _EarningsModalIconButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final DriverColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.backgroundAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: colors.textMuted),
        ),
      ),
    );
  }
}

class _EarningsModalStatusBadge extends StatelessWidget {
  const _EarningsModalStatusBadge({
    required this.statusKind,
    required this.colors,
    required this.typography,
  });

  final DriverStatusKind statusKind;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final (label, tint) = switch (statusKind) {
      DriverStatusKind.online => (DriverStrings.online, colors.success),
      DriverStatusKind.onBreak => (DriverStrings.onBreak, colors.warning),
      DriverStatusKind.offline => (DriverStrings.offline, colors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: typography.labelLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsModalZoneChip extends StatelessWidget {
  const _EarningsModalZoneChip({
    required this.zoneName,
    required this.colors,
    required this.typography,
  });

  final String zoneName;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 14, color: colors.textMuted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              zoneName,
              style: typography.labelMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsModalStatPill extends StatelessWidget {
  const _EarningsModalStatPill({
    required this.icon,
    required this.label,
    required this.colors,
    required this.typography,
  });

  final IconData icon;
  final String label;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(DriverRadius.pill),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.labelMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffProfileChip extends StatelessWidget {
  const _TariffProfileChip({
    required this.label,
    required this.isActive,
    required this.colors,
    required this.typography,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? colors.primary : colors.card.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(DriverRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DriverRadius.pill),
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : colors.border.withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.md,
              vertical: DriverSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive) ...[
                  Icon(Icons.check_rounded, size: 14, color: colors.onPrimary),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: typography.labelMedium.copyWith(
                    color: isActive ? colors.onPrimary : colors.text,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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

class _TariffDetailsSheet extends StatefulWidget {
  const _TariffDetailsSheet({
    required this.profile,
    required this.profiles,
    required this.driverId,
    required this.colors,
    required this.typo,
    required this.onEdit,
    required this.onSwitchProfile,
  });

  final DriverRateProfile? profile;
  final List<DriverRateProfile> profiles;
  final String? driverId;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onEdit;
  final Future<void> Function(String profileId) onSwitchProfile;

  @override
  State<_TariffDetailsSheet> createState() => _TariffDetailsSheetState();
}

class _TariffDetailsSheetState extends State<_TariffDetailsSheet> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final driverColors = DriverColors.fromTheme(widget.colors);
    final driverTypo = DriverTypography.fromTheme(widget.typo);
    final profile = widget.profile;
    final base = profile?.baseFare ?? 0;
    final perKm = profile?.perKmRate ?? 0;
    final perMin = profile?.perMinRate ?? 0;
    final perMinWait = profile?.waitingRate ?? 0;
    final returnDiscount = profile?.returnDiscountPct ?? 0;
    final hasMultipleProfiles = widget.profiles.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.md,
        0,
        DriverSpacing.md,
        DriverSpacing.md,
      ),
      child: Container(
        decoration: _EarningsModalStyle.cardShell(driverColors),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EarningsModalHandle(colors: driverColors),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DriverSpacing.lg,
                0,
                DriverSpacing.md,
                DriverSpacing.md,
              ),
              child: Row(
                children: [
                  _EarningsModalSoftIcon(
                    icon: Icons.local_taxi_outlined,
                    colors: driverColors,
                  ),
                  const SizedBox(width: DriverSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.profileName ?? DriverStrings.standardTariff,
                          style: driverTypo.titleSmall.copyWith(
                            color: driverColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          DriverStrings.activeTariff,
                          style: driverTypo.labelSmall.copyWith(
                            color: driverColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _EarningsModalIconButton(
                    icon: Icons.close_rounded,
                    colors: driverColors,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DriverSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(DriverSpacing.lg),
                decoration: _EarningsModalStyle.insetPanel(driverColors),
                child: Column(
                  children: [
                    _RateRow(
                      label: DriverStrings.pricingBase,
                      value: '€${base.toStringAsFixed(2)}',
                      colors: driverColors,
                      typo: driverTypo,
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    _RateRow(
                      label: DriverStrings.pricingPerKm,
                      value: '€${perKm.toStringAsFixed(2)}',
                      colors: driverColors,
                      typo: driverTypo,
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    _RateRow(
                      label: DriverStrings.pricingPerMin,
                      value: '€${perMin.toStringAsFixed(2)}',
                      colors: driverColors,
                      typo: driverTypo,
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    _RateRow(
                      label: DriverStrings.pricingWaitPerMin,
                      value: '€${perMinWait.toStringAsFixed(2)}',
                      colors: driverColors,
                      typo: driverTypo,
                    ),
                    if (returnDiscount > 0) ...[
                      const SizedBox(height: DriverSpacing.md),
                      _RateRow(
                        label: DriverStrings.pricingReturnTripDiscount,
                        value: '$returnDiscount%',
                        colors: driverColors,
                        typo: driverTypo,
                        isHighlighted: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasMultipleProfiles) ...[
              const SizedBox(height: DriverSpacing.lg),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DriverSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DriverStrings.pricingSwitchTariff,
                    style: driverTypo.labelSmall.copyWith(
                      color: driverColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DriverSpacing.sm),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DriverSpacing.lg),
                child: Wrap(
                  spacing: DriverSpacing.sm,
                  runSpacing: DriverSpacing.sm,
                  children: widget.profiles.map((p) {
                    final isActive = p.id == profile?.id;
                    return _TariffProfileChip(
                      label: p.profileName,
                      isActive: isActive,
                      colors: driverColors,
                      typography: driverTypo,
                      onTap: _switching || isActive
                          ? null
                          : () async {
                              setState(() => _switching = true);
                              await widget.onSwitchProfile(p.id);
                              if (mounted) {
                                setState(() => _switching = false);
                              }
                            },
                    );
                  }).toList(),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(
                DriverSpacing.lg,
                DriverSpacing.lg,
                DriverSpacing.lg,
                DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              child: FilledButton.icon(
                onPressed: _switching ? null : widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  DriverStrings.pricingEditThisTariff,
                  style: driverTypo.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: DriverRadius.mdAll,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final DriverColors colors;
  final DriverTypography typo;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: typo.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        Text(
          value,
          style: typo.bodyMedium.copyWith(
            color: isHighlighted ? colors.success : colors.text,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
