import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_otp_input.dart';
import '../ui/driver_status_banner.dart';
import '../ui/driver_text_field.dart';
import 'driver_login_otp_keypad.dart';

/// Trust Screen form — email + OTP steps (presentation only).
class DriverTrustScreenBody extends StatelessWidget {
  const DriverTrustScreenBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.compact,
    required this.otpSent,
    required this.loading,
    required this.emailController,
    required this.otpController,
    required this.error,
    required this.successMessage,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onResendOtp,
    required this.onChangeEmail,
    required this.onPasteOtp,
    required this.onOtpDigit,
    required this.onOtpBackspace,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool compact;
  final bool otpSent;
  final bool loading;
  final TextEditingController emailController;
  final TextEditingController otpController;
  final String? error;
  final String? successMessage;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onResendOtp;
  final VoidCallback onChangeEmail;
  final VoidCallback onPasteOtp;
  final ValueChanged<String> onOtpDigit;
  final VoidCallback onOtpBackspace;

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
          child: AnimatedSwitcher(
            duration: DriverMotion.standard,
            switchInCurve: DriverMotion.enterCurve,
            switchOutCurve: DriverMotion.standardCurve,
            child: otpSent ? _buildOtpStep(context) : _buildEmailStep(context),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(BuildContext context) {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DriverStrings.loginFormTitle,
          style: (compact ? typography.headlineMedium : typography.displaySmall)
              .copyWith(color: colors.text),
        ).driverFadeSlideIn(staggerIndex: 0),
        const SizedBox(height: DriverSpacing.sm),
        Text(
          DriverStrings.loginEmailSubtitle,
          style: typography.bodyLarge.copyWith(color: colors.textSecondary),
        ).driverFadeSlideIn(staggerIndex: 1),
        const SizedBox(height: DriverSpacing.xl),
        DriverTextField(
          controller: emailController,
          colors: colors,
          typography: typography,
          hint: DriverStrings.loginEmailHint,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => onSendOtp(),
        ),
        ..._statusSection(),
        const SizedBox(height: DriverSpacing.lg),
        DriverButton(
          label: DriverStrings.loginCtaStart,
          icon: Icons.arrow_forward_rounded,
          onPressed: loading ? null : onSendOtp,
          loading: loading,
          size: DriverButtonSize.lg,
          colors: colors,
          typography: typography,
        ).driverFadeSlideIn(staggerIndex: 2),
        const SizedBox(height: DriverSpacing.lg),
        Text(
          DriverStrings.loginNewHere,
          textAlign: TextAlign.center,
          style: typography.bodySmall.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildOtpStep(BuildContext context) {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DriverStrings.loginFormTitleOtp,
          style: typography.headlineMedium.copyWith(color: colors.text),
        ),
        const SizedBox(height: DriverSpacing.sm),
        Text(
          DriverStrings.loginOtpSubtitle,
          style: typography.bodyLarge.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DriverSpacing.xl),
        ListenableBuilder(
          listenable: otpController,
          builder: (context, _) => DriverOtpInput(
            code: otpController.text,
            colors: colors,
            typography: typography,
          ),
        ),
        const SizedBox(height: DriverSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: loading ? null : onPasteOtp,
            icon: Icon(
              Icons.content_paste_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
            label: Text(
              DriverStrings.loginPasteCode,
              style: typography.labelLarge.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: DriverSpacing.sm),
        DriverLoginOtpKeypad(
          colors: colors,
          typography: typography,
          enabled: !loading,
          onDigit: onOtpDigit,
          onBackspace: onOtpBackspace,
        ),
        ..._statusSection(),
        const SizedBox(height: DriverSpacing.lg),
        DriverButton(
          label: DriverStrings.loginCtaConfirm,
          onPressed: loading ? null : onVerifyOtp,
          loading: loading,
          size: DriverButtonSize.lg,
          colors: colors,
          typography: typography,
        ),
        const SizedBox(height: DriverSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: loading ? null : onResendOtp,
              child: Text(
                DriverStrings.loginResendCode,
                style: typography.labelLarge.copyWith(color: colors.primary),
              ),
            ),
            Text(
              '·',
              style: typography.labelLarge.copyWith(color: colors.textMuted),
            ),
            TextButton(
              onPressed: loading ? null : onChangeEmail,
              child: Text(
                DriverStrings.loginChangeEmail,
                style: typography.labelLarge.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _statusSection() {
    return [
      if (successMessage != null) ...[
        const SizedBox(height: DriverSpacing.lg),
        DriverStatusBanner(
          message: successMessage!,
          colors: colors,
          typography: typography,
          tone: DriverStatusBannerTone.success,
        ).driverSuccessPop(),
      ],
      if (error != null) ...[
        const SizedBox(height: DriverSpacing.lg),
        DriverStatusBanner(
          message: error!,
          colors: colors,
          typography: typography,
          tone: DriverStatusBannerTone.error,
        ),
      ],
    ];
  }
}
