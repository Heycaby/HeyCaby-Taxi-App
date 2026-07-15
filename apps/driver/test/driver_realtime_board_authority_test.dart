import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driver realtime board authority', () {
    final boardSource = File(
      'lib/widgets/driver_scheduled_rides_realtime_listener.dart',
    ).readAsStringSync();
    final shellSource =
        File('lib/widgets/driver_shell.dart').readAsStringSync();

    test('uses one ride_requests subscription for all Driver boards', () {
      expect(
        RegExp("table: 'ride_requests'").allMatches(boardSource).length,
        1,
      );
      expect(boardSource, contains('invalidateTaxiThruProviders(ref)'));
      expect(boardSource, contains('invalidateTodayRideProviders(ref)'));
      expect(boardSource, contains('scheduledRidesProvider'));
      expect(shellSource, isNot(contains('DriverTaxiThruRealtimeListener')));
    });

    test('keeps reconnect recovery and driver-scoped invite delivery', () {
      expect(boardSource, contains('driverResyncGenerationProvider'));
      expect(boardSource, contains("channel('driver-ride-board-\$userId')"));
      expect(shellSource, contains('RideInviteRealtimeListener'));
    });
  });
}
