import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_skeleton.dart';
import '../utils/driver_tariff_profile_slots.dart';
import 'driver_hub_assets.dart';
import 'driver_performance_flow_common.dart';

/// **Rate Control** — hub-style tariff editor (icon-first, one profile at a time).
class DriverRateControlBody extends StatelessWidget {
  const DriverRateControlBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.tokenColors,
    required this.tokenTypo,
    required this.loading,
    required this.errorMessage,
    required this.presetBanner,
    required this.profiles,
    required this.selectedProfileId,
    required this.onProfileSelected,
    required this.baseFieldBuilder,
    required this.kmFieldBuilder,
    required this.minFieldBuilder,
    required this.waitFieldBuilder,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens tokenColors;
  final HeyCabyTypography tokenTypo;
  final bool loading;
  final String? errorMessage;
  final Widget? presetBanner;
  final List<DriverRateProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<String> onProfileSelected;
  final Widget Function(DriverRateProfile profile) baseFieldBuilder;
  final Widget Function(DriverRateProfile profile) kmFieldBuilder;
  final Widget Function(DriverRateProfile profile) minFieldBuilder;
  final Widget Function(DriverRateProfile profile) waitFieldBuilder;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final sorted = sortTariffProfiles(profiles);
    final selected = sorted.cast<DriverRateProfile?>().firstWhere(
          (p) => p!.id == selectedProfileId,
          orElse: () => sorted.isEmpty ? null : sorted.first,
        );

    return DriverPerformanceFlowScaffold(
      title: DriverStrings.tariffEditorTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(
              child: DriverSkeleton(colors: colors, width: 200, height: 24),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xxl),
                    child: Text(
                      errorMessage!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    DriverSpacing.screenEdge,
                    DriverSpacing.md,
                    DriverSpacing.screenEdge,
                    bottomPad + 100,
                  ),
                  children: [
                    if (presetBanner != null) ...[
                      presetBanner!.driverFadeSlideIn(staggerIndex: 0),
                      const SizedBox(height: DriverSpacing.lg),
                    ],
                    _TariffEditorHero(
                      colors: tokenColors,
                      typography: tokenTypo,
                    ).driverFadeSlideIn(staggerIndex: 1),
                    const SizedBox(height: DriverSpacing.lg),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < sorted.length; i++) ...[
                            if (i > 0) const SizedBox(width: DriverSpacing.sm),
                            _TariffProfilePickerChip(
                              profile: sorted[i],
                              selected: sorted[i].id == selected?.id,
                              colors: tokenColors,
                              typo: tokenTypo,
                              onTap: () => onProfileSelected(sorted[i].id),
                            ),
                          ],
                        ],
                      ),
                    ).driverFadeSlideIn(staggerIndex: 2),
                    if (selected != null) ...[
                      const SizedBox(height: DriverSpacing.lg),
                      DriverTariffProfileHubEditor(
                        profile: selected,
                        colors: colors,
                        typography: typography,
                        tokenColors: tokenColors,
                        tokenTypo: tokenTypo,
                        baseField: baseFieldBuilder(selected),
                        kmField: kmFieldBuilder(selected),
                        minField: minFieldBuilder(selected),
                        waitField: waitFieldBuilder(selected),
                      ).driverFadeSlideIn(staggerIndex: 3),
                    ],
                  ],
                ),
      bottomBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.sm,
          DriverSpacing.screenEdge,
          DriverSpacing.md,
        ),
        child: DriverButton(
          label: saving
              ? DriverStrings.savingTariffs
              : DriverStrings.saveAllTariffs,
          icon: Icons.save_outlined,
          onPressed: saving || profiles.isEmpty ? null : onSave,
          loading: saving,
          size: DriverButtonSize.lg,
          colors: colors,
          typography: typography,
        ),
      ),
    );
  }
}

class _TariffEditorHero extends StatelessWidget {
  const _TariffEditorHero({
    required this.colors,
    required this.typography,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.55),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                DriverHubAssets.setTariff,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.speed_rounded,
                  color: colors.accent,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Text(
              DriverStrings.tariffEditorSubtitle,
              style: typography.bodyMedium.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffProfilePickerChip extends StatelessWidget {
  const _TariffProfilePickerChip({
    required this.profile,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final DriverRateProfile profile;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slot = slotForProfileName(profile.profileName);
    final icon = slot.icon;
    final title = tariffProfileDisplayTitle(profile.profileName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.accent : colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.onAccent : colors.textMid,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: typo.titleSmall.copyWith(
                  color: selected ? colors.onAccent : colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hub-style editor for one tariff profile (hero per-km + icon grid).
class DriverTariffProfileHubEditor extends StatelessWidget {
  const DriverTariffProfileHubEditor({
    super.key,
    required this.profile,
    required this.colors,
    required this.typography,
    required this.tokenColors,
    required this.tokenTypo,
    required this.baseField,
    required this.kmField,
    required this.minField,
    required this.waitField,
  });

  final DriverRateProfile profile;
  final DriverColors colors;
  final DriverTypography typography;
  final HeyCabyColorTokens tokenColors;
  final HeyCabyTypography tokenTypo;
  final Widget baseField;
  final Widget kmField;
  final Widget minField;
  final Widget waitField;

  @override
  Widget build(BuildContext context) {
    final slot = slotForProfileName(profile.profileName);
    final title = tariffProfileDisplayTitle(profile.profileName);
    final subtitle = slot == DriverTariffProfileSlot.other
        ? null
        : slot.subtitle();

    return Container(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.55),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(slot.icon, color: colors.primary, size: 24),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: typography.bodySmall.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (profile.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    DriverStrings.active,
                    style: typography.labelSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DriverSpacing.lg),
          Center(
            child: Column(
              children: [
                Text(
                  '€${profile.perKmRate.toStringAsFixed(2)}',
                  style: typography.displaySmall.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                Text(
                  DriverStrings.ratePerKm,
                  style: typography.titleSmall.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          Row(
            children: [
              Expanded(child: baseField),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(child: kmField),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Row(
            children: [
              Expanded(child: minField),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(child: waitField),
            ],
          ),
        ],
      ),
    );
  }
}

/// Legacy card kept for visual previews/tests.
class DriverTariffProfileEditorCard extends StatelessWidget {
  const DriverTariffProfileEditorCard({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.baseField,
    required this.kmField,
    required this.minField,
    required this.waitField,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final Widget baseField;
  final Widget kmField;
  final Widget minField;
  final Widget waitField;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.55),
        borderRadius: DriverRadius.lgAll,
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          Row(
            children: [
              Expanded(child: baseField),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(child: kmField),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Row(
            children: [
              Expanded(child: minField),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(child: waitField),
            ],
          ),
        ],
      ),
    );
  }
}
