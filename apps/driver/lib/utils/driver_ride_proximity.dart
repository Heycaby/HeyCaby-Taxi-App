import 'package:geolocator/geolocator.dart';

import '../providers/driver_state_provider.dart';

/// Assist radius for pickup arrival (L2: 100–300 m band; default midpoint).
const double kDriverPickupAssistRadiusM = 200;

/// Assist radius for destination / complete ride prompt.
const double kDriverDestinationAssistRadiusM = 200;

enum DriverRideProximityAssist {
  none,
  nearPickup,
  nearDestination,
}

double distanceToTargetMeters({
  required double lat,
  required double lng,
  required double targetLat,
  required double targetLng,
}) {
  return Geolocator.distanceBetween(lat, lng, targetLat, targetLng);
}

/// Resolves proximity assist for active ride phases (assist-only — no auto API).
DriverRideProximityAssist resolveRideProximityAssist({
  required DriverAppState appState,
  required double? driverLat,
  required double? driverLng,
  required double? pickupLat,
  required double? pickupLng,
  required double? destinationLat,
  required double? destinationLng,
  double pickupRadiusM = kDriverPickupAssistRadiusM,
  double destinationRadiusM = kDriverDestinationAssistRadiusM,
}) {
  if (driverLat == null || driverLng == null) return DriverRideProximityAssist.none;

  switch (appState) {
    case DriverAppState.assigned:
      if (pickupLat == null || pickupLng == null) {
        return DriverRideProximityAssist.none;
      }
      final pickupDistance = distanceToTargetMeters(
        lat: driverLat,
        lng: driverLng,
        targetLat: pickupLat,
        targetLng: pickupLng,
      );
      if (pickupDistance <= pickupRadiusM) {
        return DriverRideProximityAssist.nearPickup;
      }
    case DriverAppState.inProgress:
      if (destinationLat == null || destinationLng == null) {
        return DriverRideProximityAssist.none;
      }
      final destDistance = distanceToTargetMeters(
        lat: driverLat,
        lng: driverLng,
        targetLat: destinationLat,
        targetLng: destinationLng,
      );
      if (destDistance <= destinationRadiusM) {
        return DriverRideProximityAssist.nearDestination;
      }
    default:
      break;
  }
  return DriverRideProximityAssist.none;
}
