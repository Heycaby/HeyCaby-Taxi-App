import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider lifecycle has one Realtime and polling owner', () {
    final scope =
        File('lib/services/rider_live_activity_scope.dart').readAsStringSync();
    final engine = File('lib/services/rider_ride_lifecycle_engine.dart')
        .readAsStringSync();
    final active =
        File('lib/screens/active_ride_screen.dart').readAsStringSync();
    final searching =
        File('lib/screens/searching_screen.dart').readAsStringSync();
    final marketplace =
        File('lib/screens/marketplace_matching_screen.dart').readAsStringSync();
    final taxiTerug =
        File('lib/widgets/taxi_terug_matching_tracker.dart').readAsStringSync();

    expect(scope, contains(".channel('rider_ride_lifecycle_engine:\$rideId')"));
    expect(scope, contains('RealtimeSubscribeStatus.subscribed'));
    expect(scope, contains("source: 'realtime_subscribed'"));
    expect(scope, contains('Timer.periodic(const Duration(seconds: 5)'));
    expect(engine, contains('RiderRideSnapshotService.fetch('));
    expect(engine, contains('riderRideBackendRecordProvider'));
    expect(engine, contains("record['driver_on_my_way_at']"));
    expect(active, contains('riderRideBackendRecordProvider'));
    expect(active, contains("row['driver_on_my_way'] == true"));
    expect(active, isNot(contains(".channel('ride_status:")));
    expect(active, isNot(contains('_startStatusRefreshTimer')));
    expect(active, isNot(contains("reason: 'periodic_poll'")));
    expect(active, isNot(contains('RiderRidePingService')));
    expect(active, isNot(contains('_pingPollTimer')));
    expect(searching, contains('riderRideBackendRecordProvider'));
    expect(searching, isNot(contains(".channel('ride_request:")));
    expect(marketplace, contains('riderRideBackendRecordProvider'));
    expect(marketplace, isNot(contains(".channel('marketplace_ride:")));
    expect(taxiTerug, contains('riderRideBackendRecordProvider'));
    expect(taxiTerug, contains('_noMatchHandled'));
    expect(taxiTerug, contains('_onNoMatchFound(cancelBackend: false)'));
    expect(taxiTerug, isNot(contains(".channel('taxi-terug-tracker:")));
    expect(taxiTerug, isNot(contains('RiderRideSnapshotService.fetch(')));
  });
}
