import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/providers/driver_state_provider.dart';
import 'package:heycaby_driver/services/driver_operational_restore_models.dart';

void main() {
  group('driverAvailabilityFromServerStatus', () {
    test('maps availability states', () {
      expect(
        driverAvailabilityFromServerStatus('available'),
        DriverAppState.onlineAvailable,
      );
      expect(
        driverAvailabilityFromServerStatus('on_ride'),
        DriverAppState.onlineAvailable,
      );
      expect(driverAvailabilityFromServerStatus('on_break'), DriverAppState.onBreak);
      expect(driverAvailabilityFromServerStatus('offline'), DriverAppState.offline);
      expect(driverAvailabilityFromServerStatus(null), DriverAppState.offline);
    });
  });

  group('driverAppStateFromRideStatus', () {
    test('maps ride phases', () {
      expect(
        driverAppStateFromRideStatus('driver_arrived'),
        DriverAppState.arrived,
      );
      expect(
        driverAppStateFromRideStatus('in_progress'),
        DriverAppState.inProgress,
      );
      expect(driverAppStateFromRideStatus('accepted'), DriverAppState.assigned);
      expect(driverAppStateFromRideStatus('assigned'), DriverAppState.assigned);
    });
  });

  group('rideRestoreRoute', () {
    test('maps app state to route', () {
      expect(
        rideRestoreRoute(DriverAppState.assigned, 'ride-1'),
        '/driver/ride/active/ride-1',
      );
      expect(
        rideRestoreRoute(DriverAppState.arrived, 'ride-1'),
        '/driver/ride/pickup/ride-1',
      );
      expect(
        rideRestoreRoute(DriverAppState.inProgress, 'ride-1'),
        '/driver/ride/progress/ride-1',
      );
      expect(
        rideRestoreRoute(DriverAppState.completingRide, 'ride-1'),
        '/driver/ride/complete/ride-1',
      );
    });
  });

  group('DriverActiveRideSnapshot.fromRow', () {
    test('parses ride row and payment_methods fallback', () {
      final snap = DriverActiveRideSnapshot.fromRow({
        'id': 'abc',
        'status': 'driver_arrived',
        'pickup_address': 'Dam',
        'pickup_lat': 52.37,
        'pickup_lng': 4.89,
        'destination_address': 'Schiphol',
        'destination_lat': 52.3,
        'destination_lng': 4.76,
        'booking_mode': 'now',
        'payment_methods': ['cash'],
        'pickup_contact_name': 'Alex',
      });

      expect(snap.rideId, 'abc');
      expect(snap.appState, DriverAppState.arrived);
      expect(snap.paymentMethod, 'cash');
      expect(snap.riderContactName, 'Alex');
      expect(snap.restoreRoute, '/driver/ride/pickup/abc');
    });
  });

  group('DriverOperationalRestoreSnapshot', () {
    test('prefers active ride state over availability', () {
      final snap = DriverOperationalRestoreSnapshot(
        availabilityState: DriverAppState.onlineAvailable,
        activeRide: DriverActiveRideSnapshot.fromRow({
          'id': 'r1',
          'status': 'in_progress',
        }),
        serverDriverStatus: 'on_ride',
      );

      expect(snap.effectiveAppState, DriverAppState.inProgress);
      expect(snap.navigationRoute, '/driver/ride/progress/r1');
    });
  });
}
