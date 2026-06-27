import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_start_shift_args.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../utils/driver_go_online_onboarding.dart';
import '../widgets/driver_settings_flow_common.dart';

/// Waiting room while the current driver is notified (5-minute secure handover).
class DriverShiftHandoverWaitingScreen extends ConsumerStatefulWidget {
  const DriverShiftHandoverWaitingScreen({
    super.key,
    required this.args,
    required this.requestId,
    required this.expiresAt,
  });

  final DriverStartShiftArgs args;
  final String requestId;
  final DateTime expiresAt;

  @override
  ConsumerState<DriverShiftHandoverWaitingScreen> createState() =>
      _DriverShiftHandoverWaitingScreenState();
}

class _DriverShiftHandoverWaitingScreenState
    extends ConsumerState<DriverShiftHandoverWaitingScreen> {
  bool _busy = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tickRemaining();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _tickRemaining());
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollOnce());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _tickRemaining() {
    if (!mounted) return;
    final now = DateTime.now().toUtc();
    setState(() {
      _remaining = widget.expiresAt.difference(now);
    });
    if (_remaining.inSeconds <= 0) {
      _pollOnce();
    }
  }

  Future<void> _pollOnce() async {
    if (_busy || !mounted) return;
    _busy = true;
    final res = await ref
        .read(driverDataServiceProvider)
        .pollShiftHandover(widget.requestId);
    _busy = false;
    if (!mounted || res == null) return;

    final status = res['status']?.toString();
    if (status == 'approved' || status == 'timed_out') {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      ref.invalidate(driverProfileProvider);
      ref.invalidate(driverComplianceProvider);
      await continueDriverGoOnlineOnboarding(
        context: context,
        ref: ref,
        resumeGoOnline: widget.args.resumeGoOnline,
      );
      return;
    }

    if (status == 'denied') {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.shiftHandoverDeniedMessage)),
      );
      return;
    }

    if (status == 'blocked_active_ride' ||
        res['error']?.toString() == 'active_ride_in_progress') {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.shiftHandoverActiveRideMessage)),
      );
    }
  }

  void _cancel() {
    if (_busy) return;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.of(context).pop(false);
  }

  String _formatRemaining(Duration remaining) {
    final total = remaining.inSeconds.clamp(0, 9999);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverSettingsFlowScaffold(
      title: DriverStrings.startShiftFlowTitle,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: _cancel,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DriverSpacing.screenEdge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    Text(
                      DriverStrings.shiftHandoverWaitingTitle,
                      textAlign: TextAlign.center,
                      style: typography.headlineSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    Text(
                      DriverStrings.shiftHandoverWaitingBody,
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    Text(
                      DriverStrings.shiftHandoverWaitingSubtitle,
                      textAlign: TextAlign.center,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    Text(
                      _formatRemaining(_remaining),
                      style: typography.displaySmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    Text(
                      DriverStrings.shiftHandoverWaitingEta,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DriverSpacing.screenEdge,
                DriverSpacing.sm,
                DriverSpacing.screenEdge,
                DriverSpacing.lg,
              ),
              child: DriverButton(
                label: DriverStrings.cancel,
                onPressed: _busy ? null : _cancel,
                variant: DriverButtonVariant.outline,
                colors: colors,
                typography: typography,
                size: DriverButtonSize.lg,
                icon: LucideIcons.x,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
