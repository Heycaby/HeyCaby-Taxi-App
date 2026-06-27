import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_map/heycaby_map.dart';

import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import 'location_service.dart';

/// Sets [BookingState.pickup] from GPS + reverse geocode when still empty.
/// Returns true when pickup is available (existing or newly filled).
Future<bool> fillPickupFromCurrentLocation(WidgetRef ref) async {
  if (ref.read(bookingProvider).pickup != null) return true;

  await ref.read(locationProvider.notifier).refreshIfPermitted();
  var pos = ref.read(locationProvider).valueOrNull;

  if (pos == null ||
      !LocationService.isInNetherlands(pos.latitude, pos.longitude)) {
    pos = await LocationService.requestAndGetLocation();
    if (pos != null &&
        LocationService.isInNetherlands(pos.latitude, pos.longitude)) {
      ref.read(locationProvider.notifier).setPosition(pos);
    } else {
      return false;
    }
  }

  try {
    final address = await ref.read(geocodingServiceProvider).reverseGeocode(
          lat: pos.latitude,
          lng: pos.longitude,
        );
    if (address == null || address.displayName.trim().isEmpty) {
      return false;
    }
    ref.read(bookingProvider.notifier).setPickup(address);
    return true;
  } catch (_) {
    return false;
  }
}
