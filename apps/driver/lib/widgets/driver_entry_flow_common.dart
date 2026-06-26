import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';

/// Shared scaffold for entry / gate surfaces.
class DriverEntryFlowScaffold extends StatelessWidget {
  const DriverEntryFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.body,
    this.onBack,
    this.centerTitle = false,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final Widget body;
  final VoidCallback? onBack;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: title,
        colors: colors,
        typography: typography,
        centerTitle: centerTitle,
        leading: onBack != null
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                onPressed: onBack,
              )
            : null,
      ),
      body: body,
    );
  }
}

/// Hero icon for readiness / update gates.
class DriverGateHeroIcon extends StatelessWidget {
  const DriverGateHeroIcon({
    super.key,
    required this.icon,
    required this.colors,
  });

  final IconData icon;
  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 34, color: colors.primary),
    );
  }
}

/// Primary + secondary gate actions.
class DriverGateActionColumn extends StatelessWidget {
  const DriverGateActionColumn({
    super.key,
    required this.colors,
    required this.typography,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriverButton(
          label: primaryLabel,
          colors: colors,
          typography: typography,
          onPressed: onPrimary,
          size: DriverButtonSize.lg,
        ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: DriverSpacing.sm),
          DriverButton(
            label: secondaryLabel!,
            colors: colors,
            typography: typography,
            onPressed: onSecondary,
            variant: DriverButtonVariant.outline,
            size: DriverButtonSize.lg,
          ),
        ],
        if (tertiaryLabel != null && onTertiary != null) ...[
          const SizedBox(height: DriverSpacing.sm),
          TextButton(
            onPressed: onTertiary,
            child: Text(
              tertiaryLabel!,
              style: typography.labelLarge.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// WebView placeholder for golden previews.
class DriverKnowledgeBasePlaceholder extends StatelessWidget {
  const DriverKnowledgeBasePlaceholder({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Getting started as a driver',
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            'Learn how to complete verification, set your tariff, and go online for your first ride.',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: colors.backgroundAlt,
              borderRadius: DriverRadius.smAll,
              border: Border.all(color: colors.border),
            ),
          ),
        ],
      ),
    ).driverFadeSlideIn(staggerIndex: 0);
  }
}
