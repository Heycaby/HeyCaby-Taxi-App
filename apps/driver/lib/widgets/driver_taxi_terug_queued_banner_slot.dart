import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_taxi_terug_queued_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import 'driver_taxi_terug_queued_banner.dart';

/// Loads queued Taxi Terug status for the driver's current ride and shows banner.
class DriverTaxiTerugQueuedBannerSlot extends ConsumerWidget {
  const DriverTaxiTerugQueuedBannerSlot({
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
    final queued = ref
        .watch(driverTaxiTerugQueuedForRideProvider(currentRideId))
        .valueOrNull;
    if (queued == null || !queued.hasQueued) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DriverTaxiTerugQueuedBanner(
        status: queued,
        colors: colors,
        typography: typography,
      ),
    );
  }
}
