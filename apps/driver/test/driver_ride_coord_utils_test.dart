import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/utils/driver_ride_coord_utils.dart';

void main() {
  group('parseDriverRidePoint', () {
    test('parses WKT POINT', () {
      final parsed = parseDriverRidePoint('POINT(4.47917 51.9225)');
      expect(parsed, (51.9225, 4.47917));
    });

    test('parses GeoJSON map', () {
      final parsed = parseDriverRidePoint({
        'type': 'Point',
        'coordinates': [4.413597, 51.820901],
      });
      expect(parsed, (51.820901, 4.413597));
    });

    test('parses GeoJSON string', () {
      final parsed = parseDriverRidePoint(
        '{"type":"Point","coordinates":[4.47917,51.9225]}',
      );
      expect(parsed, (51.9225, 4.47917));
    });
  });
}
