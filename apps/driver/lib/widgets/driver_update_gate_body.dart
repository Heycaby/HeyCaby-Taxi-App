import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'heycaby_driver_logo.dart';
import 'driver_entry_flow_common.dart';

/// **Update Gate** — iOS below minimum (presentation only).
class DriverUpdateGateBody extends StatelessWidget {
  const DriverUpdateGateBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.title,
    required this.body,
    required this.footer,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String title;
  final String body;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DriverSpacing.screenEdge,
            DriverSpacing.xl,
            DriverSpacing.screenEdge,
            DriverSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: HeyCabyDriverLogo(width: 180)),
              const SizedBox(height: DriverSpacing.xl),
              Center(
                child: DriverGateHeroIcon(
                  icon: Icons.system_update_rounded,
                  colors: colors,
                ),
              ).driverFadeSlideIn(staggerIndex: 0),
              const SizedBox(height: DriverSpacing.xl),
              Text(
                title,
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ).driverFadeSlideIn(staggerIndex: 1),
              const SizedBox(height: DriverSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: typography.bodyLarge.copyWith(
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DriverSpacing.md),
              Text(
                footer,
                style: typography.bodySmall.copyWith(
                  color: colors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
