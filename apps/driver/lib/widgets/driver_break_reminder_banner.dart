import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_data_service.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';

/// Warm amber banner when continuous driving reaches [DriverShiftStats.breakReminderIntervalMinutes].
/// Tapping Pauze sets status to on_break. Auto-hides after [autoDismissSeconds] if ignored.
class DriverBreakReminderBanner extends ConsumerStatefulWidget {
  const DriverBreakReminderBanner({super.key});

  static const int autoDismissSeconds = 7;

  @override
  ConsumerState<DriverBreakReminderBanner> createState() =>
      _DriverBreakReminderBannerState();
}

class _DriverBreakReminderBannerState
    extends ConsumerState<DriverBreakReminderBanner> {
  Timer? _tick;
  Timer? _autoDismiss;
  bool _dismissedForThisStreak = false;
  bool _autoDismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _autoDismiss?.cancel();
    super.dispose();
  }

  int _interval(DriverShiftStats? stats) {
    final v = stats?.breakReminderIntervalMinutes ?? 120;
    return v <= 0 ? 120 : v;
  }

  bool _eligible(DriverShiftStats? stats, bool online, bool onBreak) {
    if (stats == null || !online || onBreak) return false;
    return stats.continuousDrivingMinutes >= _interval(stats);
  }

  Future<void> _onPauze() async {
    _autoDismiss?.cancel();
    setState(() {
      _dismissedForThisStreak = true;
      _autoDismissScheduled = false;
    });
    try {
      final pos = await requestAndGetLocation();
      if (!mounted) return;
      await ref.read(driverApiProvider).setStatus(
            status: 'on_break',
            lat: pos?.latitude,
            lng: pos?.longitude,
          );
      if (!mounted) return;
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onBreak);
      SoundService().playStatusOnBreak();
      ref.invalidate(driverShiftStatsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.endShiftDetail)),
        );
      }
    }
  }

  void _syncDismissState(DriverShiftStats? stats, bool eligible) {
    // Below threshold again (e.g. after break): allow a new reminder.
    if (stats != null && stats.continuousDrivingMinutes < _interval(stats)) {
      if (_autoDismiss != null || _autoDismissScheduled) {
        _autoDismiss?.cancel();
        _autoDismiss = null;
        _autoDismissScheduled = false;
      }
      if (_dismissedForThisStreak) {
        _dismissedForThisStreak = false;
      }
      return;
    }

    if (!eligible) {
      _autoDismiss?.cancel();
      _autoDismiss = null;
      _autoDismissScheduled = false;
      return;
    }

    final show = eligible && !_dismissedForThisStreak;
    if (show && !_autoDismissScheduled) {
      _autoDismissScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _autoDismiss?.cancel();
        _autoDismiss = Timer(
          const Duration(seconds: DriverBreakReminderBanner.autoDismissSeconds),
          () {
            if (!mounted) return;
            setState(() => _dismissedForThisStreak = true);
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);
    final stats = ref.watch(driverShiftStatsProvider).valueOrNull;

    final online = driver.appState == DriverAppState.onlineAvailable;
    final onBreak = driver.appState == DriverAppState.onBreak;
    final eligible = _eligible(stats, online, onBreak);

    _syncDismissState(stats, eligible);

    if (!eligible || _dismissedForThisStreak) {
      return const SizedBox.shrink();
    }

    final hours = (stats!.continuousDrivingMinutes ~/ 60).clamp(1, 24);
    final body = DriverStrings.shiftBreakReminderBodyHours(hours);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.accentL,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.warning.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(AppIcons.bellRing, color: colors.warning, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DriverStrings.shiftBreakReminderTitle,
                    style: typo.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: typo.bodySmall
                        .copyWith(color: colors.textMid, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.card,
                foregroundColor: colors.text,
                disabledBackgroundColor: colors.border,
                disabledForegroundColor: colors.textSoft,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.border),
                ),
              ),
              onPressed: () {
                HapticService.mediumTap();
                _onPauze();
              },
              child: Text(DriverStrings.pauze, style: typo.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}
