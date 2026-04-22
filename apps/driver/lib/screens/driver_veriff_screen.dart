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

  /// Records when the driver started Veriff + creates an admin support ticket.
  Future<void> _recordVeriffStarted(String driverId) async {
    final uid = HeyCabySupabase.client.auth.currentUser?.id;
    try {
      await HeyCabySupabase.client
          .from('drivers')
          .update({'veriff_started_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', driverId);
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

    setState(() {
      _loading = true;
      _message = null;
    });
    final driverId = await ref.read(driverIdProvider.future);

    // Hosted Verification Page (static URL) — no Edge Function session creation.
    final hvp = kDriverVeriffHvpUrl.trim();
    if (hvp.isNotEmpty) {
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
      return;
    }

    final session =
        await ref.read(driverDataServiceProvider).startVeriffVerificationAndPersist();
    if (!mounted) return;
    setState(() => _loading = false);
    if (session == null) {
      setState(() {
        _message = DriverStrings.veriffOpenFailed;
        _messageOk = false;
      });
      return;
    }
    final uri = Uri.parse(session.url);
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
    }
    ref.invalidate(driverComplianceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.veriffScreenTitle,
          style: typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 56,
                color: colors.accent,
              ),
              const SizedBox(height: 16),
              Text(
                DriverStrings.veriffScreenIntro,
                style: typo.bodyMedium.copyWith(
                  color: colors.textSoft,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                decoration: BoxDecoration(
                  color: colors.accentL,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      DriverStrings.veriffScreenComeBackTitle,
                      textAlign: TextAlign.center,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      DriverStrings.veriffScreenComeBackBody,
                      textAlign: TextAlign.center,
                      style: typo.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_messageOk == true)
                        ? colors.success.withValues(alpha: 0.12)
                        : colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message!,
                    style: typo.bodySmall.copyWith(
                      color: (_messageOk == true) ? colors.success : colors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _startVeriff,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                child: _loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onAccent,
                        ),
                      )
                    : Text(
                        DriverStrings.veriffScreenContinue,
                        style: typo.labelLarge.copyWith(
                          color: colors.onAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
