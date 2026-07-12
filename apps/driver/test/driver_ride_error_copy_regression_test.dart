import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driver ride error copy regression', () {
    final rideScreenSources = [
      File('lib/screens/active_ride_screen.dart').readAsStringSync(),
      File('lib/screens/at_pickup_screen.dart').readAsStringSync(),
      File('lib/screens/ride_in_progress_screen.dart').readAsStringSync(),
      File('lib/screens/new_ride_request_screen.dart').readAsStringSync(),
    ].join('\n');

    test('does not expose raw exception details in ride snackbars', () {
      expect(rideScreenSources, isNot(contains(r'$e')));
      expect(rideScreenSources,
          isNot(contains('DriverAcceptRideException catch (e)')));
      expect(rideScreenSources, contains('driverRideLifecycleErrorMessage'));
      expect(rideScreenSources, contains('acceptRideErrorMessageFor'));
      expect(rideScreenSources, contains('rideRequestLoadFailedMessage'));
      expect(rideScreenSources, contains('requestStatusUpdateFailedMessage'));
    });
  });
}
