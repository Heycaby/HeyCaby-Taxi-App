import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/providers/driver_state_provider.dart';
import 'package:heycaby_driver/services/location_service.dart';

void main() {
  group('shouldTrackDriverLocation (Program 3A)', () {
    test('tracks when online and waiting for rides', () {
      expect(
        shouldTrackDriverLocation(DriverAppState.onlineAvailable),
        isTrue,
      );
    });

    test('tracks during active ride phases', () {
      for (final state in [
        DriverAppState.assigned,
        DriverAppState.arrived,
        DriverAppState.inProgress,
        DriverAppState.completingRide,
      ]) {
        expect(shouldTrackDriverLocation(state), isTrue, reason: '$state');
      }
    });

    test('does not track when offline or on break', () {
      expect(shouldTrackDriverLocation(DriverAppState.offline), isFalse);
      expect(shouldTrackDriverLocation(DriverAppState.onBreak), isFalse);
    });

    test('does not track when logged out or onboarding', () {
      expect(shouldTrackDriverLocation(DriverAppState.loggedOut), isFalse);
      expect(
        shouldTrackDriverLocation(DriverAppState.onboardingIncomplete),
        isFalse,
      );
    });
  });
}
