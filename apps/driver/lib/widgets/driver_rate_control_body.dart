import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_skeleton.dart';
import 'driver_performance_flow_common.dart';

/// **Rate Control** — set fares confidently.
class DriverRateControlBody extends StatelessWidget {
  const DriverRateControlBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.errorMessage,
    required this.presetBanner,
    required this.profileEditors,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? errorMessage;
  final Widget? presetBanner;
  final List<Widget> profileEditors;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverPerformanceFlowScaffold(
      title: DriverStrings.tariffEditorTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(
              child: DriverSkeleton(colors: colors, width: 200, height: 24))
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
                    Text(
                      DriverStrings.tariffEditorSubtitle,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ).driverFadeSlideIn(staggerIndex: 1),
                    const SizedBox(height: DriverSpacing.sm),
                    ...profileEditors.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: DriverSpacing.md,
                            ),
                            child: e.value.driverFadeSlideIn(
                              staggerIndex: e.key + 2,
                            ),
                          ),
                        ),
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
          onPressed: saving ? null : onSave,
          loading: saving,
          size: DriverButtonSize.lg,
          colors: colors,
          typography: typography,
        ),
      ),
    );
  }
}

/// One tariff profile editor card — field widgets built by screen.
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
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
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
