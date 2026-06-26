import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_entry_flow_common.dart';

/// **Readiness Gate** — what's blocking go-live.
class DriverReadinessGateBody extends StatelessWidget {
  const DriverReadinessGateBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.title,
    required this.body,
    required this.checklist,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    required this.onBackHome,
    this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String title;
  final String body;
  final Widget? checklist;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback onBackHome;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverEntryFlowScaffold(
      title: DriverStrings.runtimeGateTitle,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.lg,
            DriverSpacing.screenEdge,
            bottomPad + DriverSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: DriverGateHeroIcon(
                  icon: Icons.rule_folder_rounded,
                  colors: colors,
                ),
              ).driverFadeSlideIn(staggerIndex: 0),
              const SizedBox(height: DriverSpacing.md),
              Text(
                title,
                style: typography.titleLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ).driverFadeSlideIn(staggerIndex: 1),
              const SizedBox(height: DriverSpacing.sm),
              Text(
                body,
                style: typography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ).driverFadeSlideIn(staggerIndex: 2),
              if (checklist != null) ...[
                const SizedBox(height: DriverSpacing.lg),
                checklist!,
              ],
              const SizedBox(height: DriverSpacing.xl),
              if (primaryLabel != null && onPrimary != null)
                DriverGateActionColumn(
                  colors: colors,
                  typography: typography,
                  primaryLabel: primaryLabel!,
                  onPrimary: onPrimary!,
                  secondaryLabel: secondaryLabel,
                  onSecondary: onSecondary,
                  tertiaryLabel: DriverStrings.runtimeGateBackHome,
                  onTertiary: onBackHome,
                )
              else
                DriverGateActionColumn(
                  colors: colors,
                  typography: typography,
                  primaryLabel: DriverStrings.runtimeGateBackHome,
                  onPrimary: onBackHome,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
