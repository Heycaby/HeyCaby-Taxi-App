import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_ride_line_provider.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

/// In-ride banner for the NEXT slot on the ride line (all booking modes).
class DriverNextRideBannerSlot extends ConsumerWidget {
  const DriverNextRideBannerSlot({
    super.key,
    required this.currentRideId,
    required this.colors,
    required this.typography,
  });

  final String currentRideId;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(driverRideLineProvider).valueOrNull;
    final next = board?.next;
    if (next == null || !next.isQueuedAfterCurrent) {
      return const SizedBox.shrink();
    }
    if (board?.now?.rideId != currentRideId &&
        ref.read(driverStateProvider).activeRideId != currentRideId) {
      return const SizedBox.shrink();
    }

    final fare = next.fareLabel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue_play_next_rounded,
                  color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DriverStrings.rideLineNextLabel,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            next.routeLabel,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          if (fare != null) ...[
            const SizedBox(height: 4),
            Text(
              '${DriverStrings.rideLineNextAfterDropOff} · $fare',
              style: typography.labelMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
