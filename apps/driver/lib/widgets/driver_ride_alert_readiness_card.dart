import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_spacing.dart';

final driverRideAlertReadinessProvider =
    FutureProvider.autoDispose<HeyCabyNotificationReadiness>((ref) async {
  return HeyCabyFcmRegistration.readiness();
});

/// Short-lived confirmation that ride alerts are configured.
/// Auto-hides after [autoDismissMinutes]; driver can dismiss early with X.
/// The green "ready" state only appears while online — not on the offline home.
class DriverRideAlertReadinessCard extends ConsumerStatefulWidget {
  const DriverRideAlertReadinessCard({super.key});

  static const int autoDismissMinutes = 5;

  @override
  ConsumerState<DriverRideAlertReadinessCard> createState() =>
      _DriverRideAlertReadinessCardState();
}

class _DriverRideAlertReadinessCardState
    extends ConsumerState<DriverRideAlertReadinessCard> {
  Timer? _autoDismiss;
  bool _hidden = false;
  bool _autoDismissScheduled = false;

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    setState(() {
      _hidden = true;
      _autoDismissScheduled = false;
    });
  }

  void _scheduleAutoDismiss() {
    if (_hidden || _autoDismissScheduled) return;
    _autoDismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hidden) return;
      _autoDismiss?.cancel();
      _autoDismiss = Timer(
        const Duration(minutes: DriverRideAlertReadinessCard.autoDismissMinutes),
        () {
          if (!mounted) return;
          setState(() => _hidden = true);
        },
      );
    });
  }

  bool _shouldShow({
    required HeyCabyNotificationReadiness status,
    required bool isOnline,
  }) {
    if (_hidden) return false;
    if (status.ready && !isOnline) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final readiness = ref.watch(driverRideAlertReadinessProvider);
    final isOnline =
        ref.watch(driverStateProvider).appState == DriverAppState.onlineAvailable;

    ref.listen<DriverData>(driverStateProvider, (previous, next) {
      final wasOnline =
          previous?.appState == DriverAppState.onlineAvailable;
      final isOnlineNow = next.appState == DriverAppState.onlineAvailable;
      if (!wasOnline && isOnlineNow) {
        _autoDismiss?.cancel();
        if (mounted) {
          setState(() {
            _hidden = false;
            _autoDismissScheduled = false;
          });
        }
      }
    });

    return readiness.maybeWhen(
      data: (status) {
        if (!_shouldShow(status: status, isOnline: isOnline)) {
          return const SizedBox.shrink();
        }
        _scheduleAutoDismiss();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DriverSpacing.md),
              decoration: BoxDecoration(
                color: status.ready
                    ? colors.card
                    : colors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: status.ready
                      ? colors.border
                      : colors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (status.ready ? colors.success : colors.warning)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          status.ready
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          color:
                              status.ready ? colors.success : colors.warning,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DriverStrings.rideAlertsTitle,
                              style: typo.titleSmall.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.ready
                                  ? DriverStrings.rideAlertsReady
                                  : DriverStrings.rideAlertsWarning,
                              style: typo.bodySmall
                                  .copyWith(color: colors.textMid),
                            ),
                          ],
                        ),
                      ),
                      if (!status.ready)
                        TextButton(
                          onPressed:
                              HeyCabyFcmRegistration.openNotificationSettings,
                          child: Text(DriverStrings.openSettings),
                        ),
                      IconButton(
                        onPressed: () {
                          HapticService.selectionClick();
                          _dismiss();
                        },
                        tooltip: DriverStrings.close,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colors.textSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ReadinessChip(
                        label: DriverStrings.rideAlertsNotifications,
                        ready: status.authorized && status.alertsEnabled,
                      ),
                      _ReadinessChip(
                        label: DriverStrings.rideAlertsSound,
                        ready: status.soundsEnabled,
                      ),
                      _ReadinessChip(
                        label: DriverStrings.rideAlertsTimeSensitive,
                        ready: status.timeSensitiveEnabled,
                      ),
                      _ReadinessChip(
                        label: DriverStrings.rideAlertsRegistered,
                        ready: status.tokenRegistered,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DriverSpacing.lg),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ReadinessChip extends ConsumerWidget {
  const _ReadinessChip({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 15,
            color: ready ? colors.success : colors.warning,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: typo.labelSmall.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
