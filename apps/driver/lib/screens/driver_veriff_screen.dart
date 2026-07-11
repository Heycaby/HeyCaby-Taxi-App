import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/driver_veriff_config.dart';
import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../utils/driver_runtime_refresh.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_veriff_trust_body.dart';
import '../widgets/veriff_terms_consent_sheet.dart';

/// Full-screen flow: terms → create Veriff session → open hosted verification in the system browser.
class DriverVeriffScreen extends ConsumerStatefulWidget {
  const DriverVeriffScreen({super.key});

  @override
  ConsumerState<DriverVeriffScreen> createState() => _DriverVeriffScreenState();
}

class _DriverVeriffScreenState extends ConsumerState<DriverVeriffScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  String? _message;
  bool? _messageOk;

  RealtimeChannel? _veriffChannel;
  bool _veriffWatchActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _veriffWatchActive && mounted) {
      ref.invalidate(driverComplianceProvider);
      ref.invalidate(driverProfileProvider);
      unawaited(refreshDriverRuntime(ref));
    }
  }

  void _subscribeVeriffRealtime(String driverId) {
    _veriffChannel?.unsubscribe();
    _veriffChannel = HeyCabySupabase.client
        .channel('drivers-veriff-$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: driverId,
          ),
          callback: (_) {
            if (!mounted) return;
            ref.invalidate(driverComplianceProvider);
            ref.invalidate(driverProfileProvider);
            unawaited(refreshDriverRuntime(ref));
          },
        )
        .subscribe();
    _veriffWatchActive = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _veriffChannel?.unsubscribe();
    super.dispose();
  }

  /// Optional Supabase `app_config` override (e.g. new Veriff HVP URL without shipping a build).
  Future<String?> _fetchAppConfigNonEmpty(String key) async {
    try {
      final res = await HeyCabySupabase.client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final v = res?['value'] as String?;
      final t = v?.trim();
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    return null;
  }

  /// Second consent step: user explicitly agrees to leave the app for Veriff’s website (Apple / AVG).
  Future<bool> _confirmLeaveAppForExternalVeriff() async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          DriverStrings.veriffExternalBrowserTitle,
          style: typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          DriverStrings.veriffExternalBrowserBody,
          style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              DriverStrings.veriffExternalBrowserCancel,
              style: typo.labelLarge.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              DriverStrings.veriffExternalBrowserContinue,
              style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Records when the driver started Veriff + creates an admin support ticket.
  Future<void> _recordVeriffStarted(String driverId) async {
    final uid = HeyCabySupabase.client.auth.currentUser?.id;
    try {
      await HeyCabySupabase.client.from('drivers').update({
        'veriff_started_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', driverId);
    } catch (_) {}

    if (uid == null) return;
    try {
      final msg = jsonEncode([
        {
          'role': 'system',
          'content': 'Driver gestart met rijbewijs-verificatie via Veriff',
          'ts': DateTime.now().toUtc().toIso8601String(),
        }
      ]);
      await HeyCabySupabase.client.from('tickets').insert({
        'user_type': 'driver',
        'user_id': uid,
        'category': 'verification',
        'priority': 'normal',
        'status': 'open',
        'context_driver_id': driverId,
        'messages': msg,
        'ai_handled': false,
      });
    } catch (_) {}
  }

  Future<void> _startVeriff() async {
    final agreed = await showVeriffTermsConsentSheet(context);
    if (!agreed || !mounted) return;

    final leaveForBrowser = await _confirmLeaveAppForExternalVeriff();
    if (!leaveForBrowser || !mounted) return;

    setState(() {
      _loading = true;
      _message = null;
    });
    final driverId = await ref.read(driverIdProvider.future);

    // HVP URL: app_config → dart-define → [kDriverVeriffHvpFallbackUrl] (never rely on Edge Function here).
    final remoteHvp = await _fetchAppConfigNonEmpty('driver_veriff_hvp_url');
    final hvp = resolveDriverVeriffHvpUrl(remoteHvp);
    final uri = Uri.parse(hvp);
    if (!mounted) return;
    setState(() => _loading = false);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (driverId != null) {
        _subscribeVeriffRealtime(driverId);
        await _recordVeriffStarted(driverId);
      }
      setState(() {
        _message = DriverStrings.veriffProcessingHint;
        _messageOk = true;
      });
    } else {
      setState(() {
        _message = DriverStrings.veriffOpenFailed;
        _messageOk = false;
      });
    }
    ref.invalidate(driverComplianceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverVeriffTrustBody(
      colors: colors,
      typography: typography,
      loading: _loading,
      message: _message,
      messageOk: _messageOk,
      onBack: () => context.pop(),
      onContinue: _startVeriff,
    );
  }
}
