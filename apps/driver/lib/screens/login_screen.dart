import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../router.dart';
import '../services/driver_session_bootstrap.dart';
import '../utils/driver_entry_navigation.dart';
import '../utils/driver_session_revoked_flow.dart';
import '../utils/driver_taxi_session_revoked_flow.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_login_hero.dart';
import '../widgets/driver_trust_screen_body.dart';

/// **Trust Screen** — make drivers trust HeyCaby within 5 seconds.
///
/// See [`SCREEN_OWNERSHIP.md`](../../docs/SCREEN_OWNERSHIP.md).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _otpVerifyInFlight = false;
  bool _otpSent = false;
  String? _error;
  String? _successMessage;

  bool _looksLikeOtpExpired(Object error) {
    final s = error.toString().toLowerCase();
    return s.contains('otp_expired') ||
        s.contains('token has expired') ||
        s.contains('expired or is invalid');
  }

  String _formatLoginError(Object error) {
    if (_looksLikeOtpExpired(error)) {
      return DriverStrings.loginOtpExpired;
    }
    final raw = error.toString().replaceFirst('AuthException: ', '').trim();
    if (raw.contains('Invalid API key') || raw.contains('401')) {
      return DriverStrings.loginConfigError;
    }
    if (raw.isEmpty) return DriverStrings.loginFailed;
    return raw
        .replaceFirst('AuthApiException(message: ', '')
        .replaceAll(', statusCode: 401, code: null)', '');
  }

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
  }

  void _onOtpChanged() {
    if (!_otpSent || _loading || _otpVerifyInFlight) return;
    final otp = _otpController.text.trim();
    if (otp.length == 6 && RegExp(r'^\d{6}$').hasMatch(otp)) {
      _verifyOTP();
    }
  }

  void _typeOtpDigit(String d) {
    if (_loading || _otpController.text.length >= 6) return;
    if (d.length != 1 || int.tryParse(d) == null) return;
    HapticService.lightTap();
    _otpController.text = _otpController.text + d;
  }

  void _typeOtpBackspace() {
    if (_loading) return;
    final t = _otpController.text;
    if (t.isEmpty) return;
    HapticService.selectionClick();
    _otpController.text = t.substring(0, t.length - 1);
  }

  Future<void> _pasteOtpFromClipboard() async {
    if (_loading) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final take = digits.length >= 6 ? digits.substring(0, 6) : digits;
    if (!RegExp(r'^\d+$').hasMatch(take)) return;
    HapticService.lightTap();
    _otpController.text = take;
  }

  void _resetToEmailStep() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _error = null;
      _successMessage = null;
    });
  }

  @override
  void dispose() {
    _otpController.removeListener(_onOtpChanged);
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = DriverStrings.loginEnterValidEmail);
      return;
    }

    HapticService.mediumTap();
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await HeyCabySupabase.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpController.clear();
        _successMessage = DriverStrings.loginOtpCheckEmail;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatLoginError(e);
        _loading = false;
      });
    }
  }

  Future<void> _resendOtpCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = DriverStrings.loginInvalidEmailFirst);
      return;
    }
    HapticService.mediumTap();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await HeyCabySupabase.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpController.clear();
        _successMessage = DriverStrings.loginNewCodeSent;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatLoginError(e);
        _loading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_loading || _otpVerifyInFlight) return;

    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      setState(() => _error = DriverStrings.loginEnterSixDigitCode);
      return;
    }

    HapticService.mediumTap();
    _otpVerifyInFlight = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final reviewOutcome = await _tryAppleReviewAuth(email, otp);
      if (reviewOutcome == true) return;
      if (reviewOutcome == false) return;

      await HeyCabySupabase.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      if (!mounted) return;
      resetSessionRevokeHandled();
      resetTaxiSessionRevokeHandled();
      final driverId = await bootstrapDriverSessionAfterAuth(ref);
      ref.read(driverStateProvider.notifier).setUser(
            HeyCabySupabase.client.auth.currentUser!.id,
            driverId,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      await navigateDriverAfterAuth(
        ref: ref,
        router: appRouter,
        context: context,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatLoginError(e);
        _loading = false;
      });
    } finally {
      _otpVerifyInFlight = false;
    }
  }

  Future<bool?> _tryAppleReviewAuth(String email, String otp) async {
    try {
      final res = await HeyCabySupabase.client.functions.invoke(
        'apple-review-auth',
        body: {'email': email, 'otp': otp},
      );
      if (res.status != 200) return null;

      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else if (data is String && data.isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) map = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }

      final accessToken = map?['access_token'] as String?;
      final refreshToken = map?['refresh_token'] as String?;
      if (accessToken == null ||
          refreshToken == null ||
          accessToken.isEmpty ||
          refreshToken.isEmpty) {
        return null;
      }

      await HeyCabySupabase.client.auth.setSession(refreshToken);

      if (!mounted) return true;
      resetSessionRevokeHandled();
      resetTaxiSessionRevokeHandled();

      final driverId = await bootstrapDriverSessionAfterAuth(ref);
      final uid = HeyCabySupabase.client.auth.currentUser?.id;
      if (uid != null) {
        ref.read(driverStateProvider.notifier).setUser(uid, driverId);
      }

      if (!mounted) return true;
      setState(() => _loading = false);
      await navigateDriverAfterAuth(
        ref: ref,
        router: appRouter,
        context: context,
      );
      return true;
    } on FunctionException catch (e) {
      if (e.status >= 500 && mounted) {
        setState(() {
          _error =
              'Sign-in service is temporarily unavailable. Try again or use your email code.';
          _loading = false;
        });
        return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.of(ref);
    final typography = DriverTypography.of(ref);
    final compact = MediaQuery.sizeOf(context).height < 720;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          DriverLoginHero(
            colors: colors,
            typography: typography,
            compact: compact || _otpSent,
          ),
          Expanded(
            child: DriverTrustScreenBody(
              colors: colors,
              typography: typography,
              compact: compact,
              otpSent: _otpSent,
              loading: _loading,
              emailController: _emailController,
              otpController: _otpController,
              error: _error,
              successMessage: _successMessage,
              onSendOtp: _sendOTP,
              onVerifyOtp: _verifyOTP,
              onResendOtp: _resendOtpCode,
              onChangeEmail: _resetToEmailStep,
              onPasteOtp: _pasteOtpFromClipboard,
              onOtpDigit: _typeOtpDigit,
              onOtpBackspace: _typeOtpBackspace,
            ),
          ),
        ],
      ),
    );
  }
}
