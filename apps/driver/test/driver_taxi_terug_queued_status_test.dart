import 'package:heycaby_driver/models/driver_taxi_terug_queued_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverTaxiTerugQueuedStatus', () {
    test('fromJson parses queued next ride', () {
      final status = DriverTaxiTerugQueuedStatus.fromJson({
        'has_queued': true,
        'ride_id': 'ride-1',
        'destination_label': 'Amsterdam',
        'estimated_pickup_minutes': 20,
        'pickup_available_min': 17,
        'pickup_available_max': 25,
        'queued_after_ride_id': 'ride-current',
      });
      expect(status.hasQueued, isTrue);
      expect(status.rideId, 'ride-1');
      expect(status.destinationLabel, 'Amsterdam');
      expect(status.queuedAfterRideId, 'ride-current');
    });
  });
}
