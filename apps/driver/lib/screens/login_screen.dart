import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_state_provider.dart';
import '../services/driver_session_bootstrap.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  /// Prevents duplicate verify when the OTP listener fires twice in one frame.
  bool _otpVerifyInFlight = false;
  bool _otpSent = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
  }

  /// When 6 digits are entered, verify immediately (no extra tap).
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
    HapticFeedback.lightImpact();
    _otpController.text = _otpController.text + d;
  }

  void _typeOtpBackspace() {
    if (_loading) return;
    final t = _otpController.text;
    if (t.isEmpty) return;
    HapticFeedback.selectionClick();
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
    HapticFeedback.lightImpact();
    _otpController.text = take;
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
      setState(() => _error = 'Please enter a valid email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await HeyCabySupabase.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _successMessage = 'Controleer je e-mail voor de 6-cijferige code';
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('AuthException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_loading || _otpVerifyInFlight) return;

    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }

    _otpVerifyInFlight = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // App Store review: server validates email+OTP against app_config, returns real session.
      final reviewOutcome = await _tryAppleReviewAuth(email, otp);
      if (reviewOutcome == true) return;
      if (reviewOutcome == false) return;

      await HeyCabySupabase.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      if (!mounted) return;
      final driverId = await bootstrapDriverSessionAfterAuth(ref);
      ref.read(driverStateProvider.notifier).setUser(
            HeyCabySupabase.client.auth.currentUser!.id,
            driverId,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/driver');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('AuthException: ', '');
        _loading = false;
      });
    } finally {
      _otpVerifyInFlight = false;
    }
  }

  /// `true` = review login finished (navigated). `false` = error shown, stop.
  /// `null` = not a review login — continue with normal email OTP.
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

      // gotrue: single-arg refresh restores full session (access + user).
      await HeyCabySupabase.client.auth.setSession(refreshToken);

      if (!mounted) return true;

      final driverId = await bootstrapDriverSessionAfterAuth(ref);
      final uid = HeyCabySupabase.client.auth.currentUser?.id;
      if (uid != null) {
        ref.read(driverStateProvider.notifier).setUser(uid, driverId);
      }

      if (!mounted) return true;
      setState(() => _loading = false);
      context.go('/driver');
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
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.border, width: 1),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Mark — subtle, readable (not heavy display type)
                Text(
                  'HEYCABY DRIVER',
                  textAlign: TextAlign.center,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(bottom: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: colors.text.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.drive_eta_rounded,
                      size: 34,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Title — Plus Jakarta: strong but not “poster” wide Syne
                Text.rich(
                  TextSpan(
                    style: typo.titleLarge.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.22,
                      letterSpacing: -0.35,
                      color: colors.text,
                    ),
                    children: [
                      const TextSpan(text: 'Rij met '),
                      TextSpan(
                        text: 'HeyCaby',
                        style: typo.titleLarge.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.22,
                          letterSpacing: -0.35,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Subtitle — mid gray + comfortable size (not washed-out textSoft)
                Text(
                  _otpSent
                      ? 'Voer de 6-cijferige code in uit je e-mail.'
                      : 'Voer je e-mailadres in en we sturen je een eenmalige code.',
                  textAlign: TextAlign.center,
                  style: typo.bodyLarge.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 36),
                // Email Field
                if (!_otpSent) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.start,
                    style: typo.bodyLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'jouw@email.nl',
                      hintStyle: typo.bodyLarge.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: colors.card,
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.accent, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                    ),
                  ),
                ],
                
                // OTP: in-app numeric keypad (no system QWERTY); slots show progress.
                if (_otpSent) ...[
                  ListenableBuilder(
                    listenable: _otpController,
                    builder: (context, _) {
                      final code = _otpController.text;
                      return Row(
                        children: List.generate(6, (i) {
                          final filled = i < code.length;
                          final active = i == code.length && code.length < 6;
                          final digit = filled ? code[i] : '';
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: i == 0 ? 0 : 4,
                                end: i == 5 ? 0 : 4,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active
                                          ? colors.accent
                                          : colors.border,
                                      width: active ? 2 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      digit,
                                      style: typo.titleLarge.copyWith(
                                        color: colors.text,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _loading ? null : _pasteOtpFromClipboard,
                      icon: Icon(
                        Icons.content_paste_rounded,
                        size: 18,
                        color: colors.textMid,
                      ),
                      label: Text(
                        'Plak code',
                        style: typo.labelLarge.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _OtpNumericKeypad(
                    colors: colors,
                    typo: typo,
                    enabled: !_loading,
                    onDigit: _typeOtpDigit,
                    onBackspace: _typeOtpBackspace,
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Success/Error Messages
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: colors.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: typo.bodyMedium.copyWith(color: colors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colors.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: typo.bodyMedium.copyWith(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Primary Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    child: _loading
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colors.onAccent,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _otpSent ? 'Bevestigen' : 'Instappen',
                                style: typo.labelLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (!_otpSent) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: colors.onAccent,
                                ),
                              ],
                            ],
                          ),
                  ),
                ),

                // "New here?" hint — shown only on the email entry step
                if (!_otpSent) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Nieuw hier? Na je eerste login doorloop je de verificatiestappen.',
                    textAlign: TextAlign.center,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.45,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],

                // Secondary Action
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {
                      _otpSent = false;
                      _otpController.clear();
                      _error = null;
                      _successMessage = null;
                    }),
                    child: Text(
                      'Ander e-mailadres gebruiken',
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Large tap targets for drivers; avoids iOS showing the full QWERTY keyboard for OTP.
class _OtpNumericKeypad extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _OtpNumericKeypad({
    required this.colors,
    required this.typo,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  Widget _key(String label, {VoidCallback? onTap, Widget? child}) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled && onTap != null ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: child ??
              Text(
                label,
                style: typo.titleLarge.copyWith(
                  color: enabled ? colors.text : colors.textSoft,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: row.map((d) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _key(
                      d,
                      onTap: () => onDigit(d),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _key('0', onTap: () => onDigit('0')),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _key(
                    '',
                    onTap: onBackspace,
                    child: Icon(
                      Icons.backspace_outlined,
                      color: enabled ? colors.textMid : colors.textSoft,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
