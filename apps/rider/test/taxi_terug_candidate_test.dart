import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/models/taxi_terug_candidate.dart';

void main() {
  group('TaxiTerugCandidate', () {
    test('fromJson parses privacy-safe card fields', () {
      final c = TaxiTerugCandidate.fromJson({
        'driver_name': 'Ahmed',
        'vehicle': 'Toyota Prius',
        'heading_to': 'Amsterdam',
        'pickup_eta_minutes': 12,
        'estimated_fare_min': 42.5,
        'estimated_fare_max': 50.0,
        'match_score': 88.2,
        'why_match': 'Closer to home after this trip',
        'driver_rating': 4.8,
      });
      expect(c, isNotNull);
      expect(c!.driverName, 'Ahmed');
      expect(c.vehicle, 'Toyota Prius');
      expect(c.headingTo, 'Amsterdam');
      expect(c.pickupEtaMinutes, 12);
      expect(c.estimatedFareMin, 42.5);
      expect(c.matchScore, 88.2);
    });

    test('fromJson parses in-transit timing fields', () {
      final c = TaxiTerugCandidate.fromJson({
        'driver_name': 'Ahmed',
        'pickup_eta_minutes': 48,
        'estimated_fare_min': 42.5,
        'estimated_fare_max': 50.0,
        'match_score': 88.2,
        'driver_rating': 4.8,
        'in_transit': true,
        'pickup_available_min': 45,
        'pickup_available_max': 53,
      });
      expect(c, isNotNull);
      expect(c!.inTransit, isTrue);
      expect(c.pickupAvailableMin, 45);
    });

    test('fromJson returns null when driver name missing', () {
      expect(TaxiTerugCandidate.fromJson({'vehicle': 'Van'}), isNull);
    });
  });
}
