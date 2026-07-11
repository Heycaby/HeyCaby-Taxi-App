import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_spacing.dart';

final driverRideAlertReadinessProvider =
    FutureProvider.autoDispose<HeyCabyNotificationReadiness>((ref) async {
  return HeyCabyFcmRegistration.readiness();
});

class DriverRideAlertReadinessCard extends ConsumerWidget {
  const DriverRideAlertReadinessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final readiness = ref.watch(driverRideAlertReadinessProvider);

    return readiness.maybeWhen(
      data: (status) => Container(
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
                    color: status.ready ? colors.success : colors.warning,
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
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                    ],
                  ),
                ),
                if (!status.ready)
                  TextButton(
                    onPressed: HeyCabyFcmRegistration.openNotificationSettings,
                    child: Text(DriverStrings.openSettings),
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
