import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';

/// **Staging Surface** — dev-only placeholder (presentation only).
class DriverStagingSurfaceBody extends StatelessWidget {
  const DriverStagingSurfaceBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.title,
    required this.icon,
    this.subtitle = 'Coming soon',
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String title;
  final IconData icon;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DriverSpacing.xl),
            child: DriverEmptyState(
              icon: icon,
              title: title,
              message: subtitle,
              colors: colors,
              typography: typography,
            ),
          ),
        ),
      ),
    );
  }
}
