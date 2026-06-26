import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../utils/driver_ride_proximity.dart';

/// Meters from current GPS to ride pickup (null when unknown).
double? readDistanceToPickupM(WidgetRef ref) {
  final driver = ref.read(driverStateProvider);
  final position = ref.read(driverLocationProvider).valueOrNull;
  if (position == null ||
      driver.pickupLat == null ||
      driver.pickupLng == null) {
    return null;
  }
  return distanceToTargetMeters(
    lat: position.latitude,
    lng: position.longitude,
    targetLat: driver.pickupLat!,
    targetLng: driver.pickupLng!,
  );
}

/// Meters from current GPS to ride pickup (reactive).
double? watchDistanceToPickupM(WidgetRef ref) {
  final driver = ref.watch(driverStateProvider);
  final position = ref.watch(driverLocationProvider).valueOrNull;
  if (position == null ||
      driver.pickupLat == null ||
      driver.pickupLng == null) {
    return null;
  }
  return distanceToTargetMeters(
    lat: position.latitude,
    lng: position.longitude,
    targetLat: driver.pickupLat!,
    targetLng: driver.pickupLng!,
  );
}
