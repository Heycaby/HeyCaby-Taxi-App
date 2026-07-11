import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/models/driver_taxi_terug_stats.dart';

void main() {
  group('DriverTaxiTerugStats', () {
    test('fromJson parses monthly dashboard payload', () {
      final stats = DriverTaxiTerugStats.fromJson({
        'ok': true,
        'period': 'month',
        'rides_completed': 12,
        'empty_km_saved': 312.5,
        'earnings_euros': 486.5,
        'month_rides': 12,
        'month_empty_km_saved': 312.5,
        'month_earnings_euros': 486.5,
        'today_rides': 1,
        'today_empty_km_saved': 18.2,
        'today_earnings_euros': 42.0,
      });
      expect(stats.ok, isTrue);
      expect(stats.monthRides, 12);
      expect(stats.monthEmptyKmSaved, 312.5);
      expect(stats.monthEarningsEuros, 486.5);
      expect(stats.hasMonthActivity, isTrue);
      expect(stats.formatEuros(486.5), '€486.50');
    });

    test('parseRpc returns null when ok is false', () {
      expect(
        DriverTaxiTerugStats.parseRpc({'ok': false, 'reason': 'not_a_driver'}),
        isNull,
      );
    });
  });
}
