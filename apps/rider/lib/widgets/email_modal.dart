import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/favorites_provider.dart';
import '../services/rider_notification_lifecycle_service.dart';

Future<bool> showEmailModal(BuildContext context, [WidgetRef? ref]) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _EmailModal(),
  );
  return result ?? false;
}

class _EmailModal extends ConsumerStatefulWidget {
  const _EmailModal();

  @override
  ConsumerState<_EmailModal> createState() => _EmailModalState();
}

class _EmailModalState extends ConsumerState<_EmailModal> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _awaitingOtp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(24),
          topEnd: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsetsDirectional.only(bottom: keyboardHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.addYourEmail,
                              style: typo.headingLarge.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: Icon(Icons.close, color: colors.textMid),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.emailOnlyUsedFor,
                        style: typo.bodyMedium.copyWith(color: colors.textMid),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.riderEmailReviewCodeHint,
                        style: typo.bodySmall.copyWith(color: colors.textSoft),
                      ),
                      if (_awaitingOtp) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.riderEmailVerificationSent,
                          style: typo.bodyMedium.copyWith(color: colors.accent),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 200,
                        autofocus: !_awaitingOtp,
                        readOnly: _awaitingOtp,
                        decoration: InputDecoration(
                          hintText: l10n.enterYourEmail,
                          hintStyle:
                              typo.bodyLarge.copyWith(color: colors.textSoft),
                          filled: true,
                          fillColor: colors.bgAlt,
                          contentPadding: const EdgeInsetsDirectional.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: colors.accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _otpController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                          signed: false,
                        ),
                        maxLength: 6,
                        autofocus: _awaitingOtp,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.riderEmailReviewCodeFieldHint,
                          hintStyle:
                              typo.bodyLarge.copyWith(color: colors.textSoft),
                          filled: true,
                          fillColor: colors.bgAlt,
                          contentPadding: const EdgeInsetsDirectional.all(16),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: colors.accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: colors.border,
                            disabledForegroundColor: colors.textMid,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: colors.onAccent,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: colors.onAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      l10n.continueButton,
                                      style: typo.labelLarge.copyWith(
                                        color: colors.onAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finishSession(Map<String, dynamic> map, String email) async {
    final identityId = map['identity_id'] as String;
    await ref.read(riderIdentityProvider.notifier).saveSession(
          token: map['session_token'] as String,
          identityId: identityId,
          email: email,
        );
    // Force immediate push registration after email login completes.
    await HeyCabyFcmRegistration.sync(appRole: 'rider');
    await RiderNotificationLifecycleService.trackEvent(
      'signup_completed',
      riderIdentityId: identityId,
      payload: <String, dynamic>{'source': 'email_modal'},
    );
    await RiderNotificationLifecycleService.trackEvent(
      'app_open',
      riderIdentityId: identityId,
      payload: <String, dynamic>{'source': 'email_modal'},
    );
    ref.invalidate(favoritesProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !_isValidEmail(email)) {
      _showError(l10n.invalidEmail);
      return;
    }

    final otp = _otpController.text.trim();
    final supabase = HeyCabySupabase.client;

    setState(() => _isLoading = true);

    try {
      if (_awaitingOtp) {
        if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
          setState(() => _isLoading = false);
          _showError(l10n.riderEmailReviewOtpSixDigitsOrEmpty);
          return;
        }
        await supabase.auth.verifyOTP(
          email: email,
          token: otp,
          type: OtpType.email,
        );
        final result = await supabase.rpc(
          'fn_create_rider_session',
          params: {'p_email': email, 'p_display_name': null},
        );
        if (result == null || result is! Map || result['success'] != true) {
          setState(() => _isLoading = false);
          _showError(l10n.failedToSaveEmail);
          return;
        }
        final map = Map<String, dynamic>.from(result);
        setState(() => _isLoading = false);
        await _finishSession(map, email);
        return;
      }

      if (otp.isNotEmpty) {
        final review = await supabase.rpc(
          'fn_create_rider_session_review',
          params: {'p_email': email, 'p_otp': otp},
        );
        if (review != null && review is Map && review['success'] == true) {
          final map = Map<String, dynamic>.from(review);
          setState(() => _isLoading = false);
          await _finishSession(map, email);
          return;
        }
        if (otp.length == 6 && RegExp(r'^\d{6}$').hasMatch(otp)) {
          try {
            await supabase.auth.verifyOTP(
              email: email,
              token: otp,
              type: OtpType.email,
            );
            final result = await supabase.rpc(
              'fn_create_rider_session',
              params: {'p_email': email, 'p_display_name': null},
            );
            if (result != null && result is Map && result['success'] == true) {
              final map = Map<String, dynamic>.from(result);
              setState(() => _isLoading = false);
              await _finishSession(map, email);
              return;
            }
          } catch (_) {
            setState(() => _isLoading = false);
            _showError(l10n.riderEmailReviewCredentialsError);
            return;
          }
        }
        setState(() => _isLoading = false);
        _showError(l10n.riderEmailReviewCredentialsError);
        return;
      }

      // Existing and new addresses follow the same verified OTP path. Merely
      // knowing that an identity exists must never authenticate its owner.
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      setState(() {
        _isLoading = false;
        _awaitingOtp = true;
      });
      if (mounted) {
        final c = ref.read(colorsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.riderEmailVerificationSent,
              style: TextStyle(color: c.bg),
            ),
            backgroundColor: c.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(l10n.failedToSaveEmail);
      if (kDebugMode) debugPrint('Email modal error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      final colors = ref.read(colorsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: colors.bg),
          ),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
