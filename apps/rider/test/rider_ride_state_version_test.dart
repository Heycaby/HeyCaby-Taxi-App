import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/services/rider_ride_state_version.dart';

void main() {
  group('RiderRideStateVersionGate', () {
    tearDown(RiderRideStateVersionGate.resetAll);

    test('accepts newer version', () {
      expect(
        RiderRideStateVersionGate.shouldApply(
          rideRequestId: 'r1',
          incomingVersion: 100,
          source: 'fcm',
        ),
        isTrue,
      );
      RiderRideStateVersionGate.markApplied(
        rideRequestId: 'r1',
        version: 100,
        source: 'fcm',
      );
      expect(
        RiderRideStateVersionGate.shouldApply(
          rideRequestId: 'r1',
          incomingVersion: 200,
          source: 'realtime',
        ),
        isTrue,
      );
    });

    test('rejects stale version', () {
      RiderRideStateVersionGate.markApplied(
        rideRequestId: 'r1',
        version: 200,
        source: 'fcm',
      );
      expect(
        RiderRideStateVersionGate.shouldApply(
          rideRequestId: 'r1',
          incomingVersion: 150,
          source: 'realtime',
        ),
        isFalse,
      );
    });

    test('rejects duplicate version', () {
      RiderRideStateVersionGate.markApplied(
        rideRequestId: 'r1',
        version: 200,
        source: 'fcm',
      );
      expect(
        RiderRideStateVersionGate.shouldApply(
          rideRequestId: 'r1',
          incomingVersion: 200,
          source: 'poll',
        ),
        isFalse,
      );
    });

    test('grace tick bypasses version gate', () {
      RiderRideStateVersionGate.markApplied(
        rideRequestId: 'r1',
        version: 200,
        source: 'fcm',
      );
      expect(
        RiderRideStateVersionGate.shouldApply(
          rideRequestId: 'r1',
          incomingVersion: 200,
          source: 'grace_tick',
        ),
        isTrue,
      );
    });
  });
}
