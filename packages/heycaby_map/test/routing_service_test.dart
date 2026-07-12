import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_map/heycaby_map.dart';

void main() {
  test('directions uses traffic profile and longitude-latitude order', () {
    final service = RoutingService(accessToken: 'test-token');

    final uri = service.buildDirectionsUri(
      fromLat: 51.9244,
      fromLng: 4.4777,
      toLat: 52.3676,
      toLng: 4.9041,
    );

    expect(
      uri.path,
      '/directions/v5/mapbox/driving-traffic/'
      '4.4777,51.9244;4.9041,52.3676',
    );
    expect(uri.queryParameters['geometries'], 'geojson');
    expect(uri.queryParameters['overview'], 'full');
    expect(uri.queryParameters['access_token'], 'test-token');
  });
}
