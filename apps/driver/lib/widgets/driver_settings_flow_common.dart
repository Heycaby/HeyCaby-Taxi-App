import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';

/// Shared scaffold for settings & profile screens.
class DriverSettingsFlowScaffold extends StatelessWidget {
  const DriverSettingsFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.subtitle,
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: onBack,
        ),
      ),
      body: body,
    );
  }
}

/// Header block with title + optional subtitle (preferences / compliance style).
class DriverSettingsHeader extends StatelessWidget {
  const DriverSettingsHeader({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.md,
        DriverSpacing.screenEdge,
        DriverSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.headlineSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
            ),
          ).driverFadeSlideIn(staggerIndex: 0),
          if (subtitle != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            Text(
              subtitle!,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ).driverFadeSlideIn(staggerIndex: 1),
          ],
        ],
      ),
    );
  }
}
