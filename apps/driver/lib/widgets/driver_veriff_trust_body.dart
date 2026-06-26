import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_banner.dart';
import 'driver_settings_flow_common.dart';

/// **Identity Verification** — trust-first Veriff entry.
class DriverVeriffTrustBody extends StatelessWidget {
  const DriverVeriffTrustBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.message,
    required this.messageOk,
    required this.onBack,
    required this.onContinue,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? message;
  final bool? messageOk;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return DriverSettingsFlowScaffold(
      title: DriverStrings.veriffScreenTitle,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          DriverSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DriverStrings.veriffScreenIntro,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                height: 1.45,
              ),
            ).driverFadeSlideIn(staggerIndex: 0),
            const SizedBox(height: DriverSpacing.xl),
            DriverCard(
              colors: colors,
              padding: const EdgeInsets.all(DriverSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    DriverStrings.veriffScreenComeBackTitle,
                    textAlign: TextAlign.center,
                    style: typography.headlineSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.md),
                  Text(
                    DriverStrings.veriffScreenComeBackBody,
                    textAlign: TextAlign.center,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ).driverFadeSlideIn(staggerIndex: 1),
            if (message != null) ...[
              const SizedBox(height: DriverSpacing.lg),
              DriverStatusBanner(
                message: message!,
                colors: colors,
                typography: typography,
                tone: messageOk == true
                    ? DriverStatusBannerTone.success
                    : DriverStatusBannerTone.error,
              ),
            ],
            const SizedBox(height: DriverSpacing.xxl),
            DriverButton(
              label: DriverStrings.veriffScreenContinue,
              icon: Icons.verified_user_outlined,
              onPressed: loading ? null : onContinue,
              loading: loading,
              size: DriverButtonSize.lg,
              colors: colors,
              typography: typography,
            ).driverFadeSlideIn(staggerIndex: 2),
          ],
        ),
      ),
    );
  }
}
