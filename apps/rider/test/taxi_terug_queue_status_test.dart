import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/models/taxi_terug_queue_status.dart';

void main() {
  group('TaxiTerugQueueStatus', () {
    test('fromJson parses queued state with pickup window', () {
      final status = TaxiTerugQueueStatus.fromJson({
        'queued_taxi_terug': true,
        'reserved_for_next_ride': true,
        'status': 'accepted',
        'estimated_pickup_minutes': 25,
        'pickup_available_min': 22,
        'pickup_available_max': 30,
        'driver_name': 'Ahmed',
        'driver_vehicle': 'Toyota Prius',
        'driver_rating': 4.9,
      });
      expect(status.queuedTaxiTerug, isTrue);
      expect(status.pickupAvailableMin, 22);
      expect(status.pickupAvailableMax, 30);
      expect(status.driverName, 'Ahmed');
    });

    test('parseRpc returns null when ok is false', () {
      expect(
        TaxiTerugQueueStatus.parseRpc({'ok': false, 'reason': 'forbidden'}),
        isNull,
      );
    });
  });
}
