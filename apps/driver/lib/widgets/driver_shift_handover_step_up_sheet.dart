import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../widgets/driver_ride_premium_style.dart';

/// Step-up before requesting Secure Shift Handover (biometric preferred, OTP fallback).
Future<String?> showDriverShiftHandoverStepUpSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DriverShiftHandoverStepUpSheet(),
  );
}

class _DriverShiftHandoverStepUpSheet extends ConsumerStatefulWidget {
  const _DriverShiftHandoverStepUpSheet();

  @override
  ConsumerState<_DriverShiftHandoverStepUpSheet> createState() =>
      _DriverShiftHandoverStepUpSheetState();
}

class _DriverShiftHandoverStepUpSheetState
    extends ConsumerState<_DriverShiftHandoverStepUpSheet> {
  final _localAuth = LocalAuthentication();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  bool _biometricAvailable = false;
  bool _showOtpFallback = false;
  String? _error;

  String? get _email =>
      HeyCabySupabase.client.auth.currentUser?.email?.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      setState(() => _biometricAvailable = canCheck && supported);
      if (_biometricAvailable) {
        await _completeWithBiometric();
      } else {
        setState(() => _showOtpFallback = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _showOtpFallback = true);
    }
  }

  Future<void> _completeWithBiometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: DriverStrings.shiftHandoverBiometricReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _showOtpFallback = true;
        });
        return;
      }
      final stepUp = await ref
          .read(driverDataServiceProvider)
          .issueShiftHandoverStepUp(method: 'biometric');
      if (!mounted) return;
      final stepUpId = stepUp?['step_up_id']?.toString();
      if (stepUp?['ok'] == true && stepUpId != null && stepUpId.isNotEmpty) {
        Navigator.of(context).pop(stepUpId);
        return;
      }
      setState(() {
        _busy = false;
        _showOtpFallback = true;
        _error = DriverStrings.shiftHandoverStepUpFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _showOtpFallback = true;
      });
    }
  }

  Future<void> _sendOtp() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      setState(() => _error = DriverStrings.shiftHandoverStepUpNoEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await HeyCabySupabase.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = DriverStrings.shiftHandoverStepUpFailed;
      });
    }
  }

  Future<void> _verifyOtpAndIssue() async {
    final email = _email;
    final otp = _otpController.text.trim();
    if (email == null || otp.length != 6) {
      setState(() => _error = DriverStrings.loginEnterSixDigitCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await HeyCabySupabase.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      final stepUp = await ref
          .read(driverDataServiceProvider)
          .issueShiftHandoverStepUp(method: 'otp');
      if (!mounted) return;
      final stepUpId = stepUp?['step_up_id']?.toString();
      if (stepUp?['ok'] == true && stepUpId != null && stepUpId.isNotEmpty) {
        Navigator.of(context).pop(stepUpId);
        return;
      }
      setState(() {
        _busy = false;
        _error = DriverStrings.shiftHandoverStepUpFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = DriverStrings.shiftHandoverStepUpFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DriverSpacing.screenEdge,
          right: DriverSpacing.screenEdge,
          bottom: MediaQuery.viewInsetsOf(context).bottom + DriverSpacing.lg,
          top: DriverSpacing.screenEdge,
        ),
        child: DriverRidePremiumStyle.glassSurface(
          colors: colors,
          borderRadius: BorderRadius.circular(20),
          blurSigma: 24,
          tintOpacity: 0.82,
          padding: const EdgeInsets.all(DriverSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DriverStrings.shiftHandoverStepUpTitle,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  DriverStrings.shiftHandoverStepUpBody,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (_busy && !_showOtpFallback) ...[
                  const SizedBox(height: DriverSpacing.xl),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_showOtpFallback) ...[
                  if (_email != null) ...[
                    const SizedBox(height: DriverSpacing.sm),
                    Text(
                      _email!,
                      style: typography.labelMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_otpSent) ...[
                    const SizedBox(height: DriverSpacing.lg),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: DriverStrings.loginEnterSixDigitCode,
                        counterText: '',
                      ),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: DriverSpacing.sm),
                  Text(
                    _error!,
                    style: typography.bodySmall.copyWith(color: colors.error),
                  ),
                ],
                if (_showOtpFallback) ...[
                  const SizedBox(height: DriverSpacing.xl),
                  if (_biometricAvailable && !_otpSent)
                    DriverButton(
                      label: DriverStrings.shiftHandoverBrandName,
                      onPressed: _busy ? null : _completeWithBiometric,
                      loading: _busy,
                      colors: colors,
                      typography: typography,
                      size: DriverButtonSize.lg,
                      icon: LucideIcons.scanFace,
                    ),
                  if (_biometricAvailable && !_otpSent)
                    const SizedBox(height: DriverSpacing.sm),
                  DriverButton(
                    label: _otpSent
                        ? DriverStrings.shiftHandoverStepUpConfirm
                        : DriverStrings.shiftHandoverStepUpUseEmail,
                    onPressed: _busy
                        ? null
                        : (_otpSent ? _verifyOtpAndIssue : _sendOtp),
                    loading: _busy,
                    colors: colors,
                    typography: typography,
                    size: DriverButtonSize.lg,
                    icon: LucideIcons.mail,
                    variant: _biometricAvailable && !_otpSent
                        ? DriverButtonVariant.outline
                        : DriverButtonVariant.primary,
                  ),
                ],
                const SizedBox(height: DriverSpacing.sm),
                DriverButton(
                  label: DriverStrings.cancel,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  variant: DriverButtonVariant.outline,
                  colors: colors,
                  typography: typography,
                  size: DriverButtonSize.lg,
                ),
              ],
            ),
        ),
      ),
    );
  }
}
