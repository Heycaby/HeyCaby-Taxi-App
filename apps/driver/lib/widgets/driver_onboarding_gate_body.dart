import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_status_banner.dart';
import '../ui/driver_text_field.dart';
import 'driver_login_hero.dart';

/// **Onboarding Gate** — register as a driver (presentation only).
class DriverOnboardingGateBody extends StatelessWidget {
  const DriverOnboardingGateBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.compact,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onSubmit,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool compact;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          Stack(
            children: [
              DriverLoginHero(
                colors: colors,
                typography: typography,
                compact: compact,
              ),
              SafeArea(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _FormSheet(
              colors: colors,
              typography: typography,
              compact: compact,
              emailController: emailController,
              passwordController: passwordController,
              loading: loading,
              error: error,
              onSubmit: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.colors,
    required this.typography,
    required this.compact,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool compact;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: DriverRadius.sheetTop,
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Transform.translate(
        offset: const Offset(0, -DriverSpacing.md),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.lg,
            DriverSpacing.screenEdge,
            DriverSpacing.screenEdge + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DriverStrings.registerDriverTitle,
                style: (compact
                        ? typography.headlineMedium
                        : typography.displaySmall)
                    .copyWith(color: colors.text),
              ).driverFadeSlideIn(staggerIndex: 0),
              const SizedBox(height: DriverSpacing.sm),
              Text(
                DriverStrings.registerDriverSubtitle,
                style:
                    typography.bodyLarge.copyWith(color: colors.textSecondary),
              ).driverFadeSlideIn(staggerIndex: 1),
              const SizedBox(height: DriverSpacing.xl),
              DriverTextField(
                controller: emailController,
                colors: colors,
                typography: typography,
                hint: DriverStrings.loginEmailHint,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ).driverFadeSlideIn(staggerIndex: 2),
              const SizedBox(height: DriverSpacing.md),
              DriverTextField(
                controller: passwordController,
                colors: colors,
                typography: typography,
                hint: DriverStrings.passwordMinSixHint,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => onSubmit(),
              ).driverFadeSlideIn(staggerIndex: 3),
              if (error != null) ...[
                const SizedBox(height: DriverSpacing.lg),
                DriverStatusBanner(
                  message: error!,
                  colors: colors,
                  typography: typography,
                  tone: DriverStatusBannerTone.error,
                ),
              ],
              const SizedBox(height: DriverSpacing.lg),
              DriverButton(
                label: DriverStrings.createAccount,
                onPressed: loading ? null : onSubmit,
                loading: loading,
                size: DriverButtonSize.lg,
                colors: colors,
                typography: typography,
              ).driverFadeSlideIn(staggerIndex: 4),
            ],
          ),
        ),
      ),
    );
  }
}
