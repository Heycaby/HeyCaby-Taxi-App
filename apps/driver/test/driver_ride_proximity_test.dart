import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/providers/driver_state_provider.dart';
import 'package:heycaby_driver/utils/driver_ride_proximity.dart';

void main() {
  group('resolveRideProximityAssist', () {
    test('detects near pickup while assigned', () {
      expect(
        resolveRideProximityAssist(
          appState: DriverAppState.assigned,
          driverLat: 52.3676,
          driverLng: 4.9041,
          pickupLat: 52.3676,
          pickupLng: 4.9050,
          destinationLat: 52.4,
          destinationLng: 4.9,
          pickupRadiusM: 200,
        ),
        DriverRideProximityAssist.nearPickup,
      );
    });

    test('detects near destination while in progress', () {
      expect(
        resolveRideProximityAssist(
          appState: DriverAppState.inProgress,
          driverLat: 52.3105,
          driverLng: 4.7683,
          pickupLat: 52.3,
          pickupLng: 4.7,
          destinationLat: 52.3105,
          destinationLng: 4.7690,
          destinationRadiusM: 200,
        ),
        DriverRideProximityAssist.nearDestination,
      );
    });

    test('returns none when coordinates missing', () {
      expect(
        resolveRideProximityAssist(
          appState: DriverAppState.assigned,
          driverLat: null,
          driverLng: 4.9,
          pickupLat: 52.3,
          pickupLng: 4.7,
          destinationLat: 52.4,
          destinationLng: 4.8,
        ),
        DriverRideProximityAssist.none,
      );
    });

    test('returns none when far from pickup', () {
      expect(
        resolveRideProximityAssist(
          appState: DriverAppState.assigned,
          driverLat: 52.0,
          driverLng: 4.0,
          pickupLat: 52.3676,
          pickupLng: 4.9041,
          destinationLat: 52.4,
          destinationLng: 4.9,
          pickupRadiusM: 200,
        ),
        DriverRideProximityAssist.none,
      );
    });
  });

  group('distanceToTargetMeters', () {
    test('returns zero for identical coordinates', () {
      expect(
        distanceToTargetMeters(
          lat: 52.3676,
          lng: 4.9041,
          targetLat: 52.3676,
          targetLng: 4.9041,
        ),
        0,
      );
    });
  });
}
