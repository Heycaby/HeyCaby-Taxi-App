import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../utils/driver_ride_proximity.dart';

export '../utils/driver_ride_proximity.dart';

/// GPS-based ride proximity assist (L2 — manual override always available).
final driverRideProximityProvider = Provider<DriverRideProximityAssist>((ref) {
  final driver = ref.watch(driverStateProvider);
  final position = ref.watch(driverLocationProvider).valueOrNull;
  return resolveRideProximityAssist(
    appState: driver.appState,
    driverLat: position?.latitude,
    driverLng: position?.longitude,
    pickupLat: driver.pickupLat,
    pickupLng: driver.pickupLng,
    destinationLat: driver.destinationLat,
    destinationLng: driver.destinationLng,
  );
});
