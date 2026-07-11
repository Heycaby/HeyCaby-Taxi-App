import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_taxi_terug_queued_status.dart';
import 'driver_data_providers.dart';

final driverTaxiTerugQueuedProvider =
    FutureProvider<DriverTaxiTerugQueuedStatus?>((ref) async {
  return ref.read(driverDataServiceProvider).fetchTaxiTerugQueueStatus();
});

/// Queued next ride that should resume after the driver finishes [completedRideId].
final driverTaxiTerugQueuedForRideProvider =
    FutureProvider.family<DriverTaxiTerugQueuedStatus?, String>(
        (ref, completedRideId) async {
  final status = await ref.watch(driverTaxiTerugQueuedProvider.future);
  if (status == null || !status.hasQueued) return null;
  if (status.queuedAfterRideId != null &&
      status.queuedAfterRideId != completedRideId) {
    return null;
  }
  return status;
});
