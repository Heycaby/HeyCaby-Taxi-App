import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_button.dart';

/// Shared scaffold for money & billing screens.
class DriverMoneyFlowScaffold extends StatelessWidget {
  const DriverMoneyFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.actions,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: title,
        colors: colors,
        typography: typography,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: onBack,
        ),
        actions: actions,
      ),
      body: body,
    );
  }
}

/// Label / value row used on billing and breakdown cards.
class DriverMoneyKeyValueRow extends StatelessWidget {
  const DriverMoneyKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
    this.valueColor,
  });

  final String label;
  final String value;
  final DriverColors colors;
  final DriverTypography typography;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DriverSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: DriverSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: typography.bodyMedium.copyWith(
                color: valueColor ?? colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Export sheet row — PDF, email, WhatsApp.
class DriverFinanceExportOption extends StatelessWidget {
  const DriverFinanceExportOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: DriverRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DriverSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DriverSpacing.md),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: DriverRadius.smAll,
                ),
                child: Icon(icon, color: colors.primary, size: 24),
              ),
              const SizedBox(width: DriverSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    ).driverFadeSlideIn(staggerIndex: 0);
  }
}

/// Bottom sheet shell for finance export options.
class DriverFinanceExportSheet extends StatelessWidget {
  const DriverFinanceExportSheet({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.children,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.sheetTop,
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.lg,
          DriverSpacing.screenEdge,
          DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: typography.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DriverSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Full-width secondary action used on billing screens.
class DriverMoneyOutlineAction extends StatelessWidget {
  const DriverMoneyOutlineAction({
    super.key,
    required this.label,
    required this.icon,
    required this.colors,
    required this.typography,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DriverButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      variant: DriverButtonVariant.outline,
      colors: colors,
      typography: typography,
    );
  }
}
