import 'dart:convert';
import 'package:http/http.dart' as http;

/// Route data returned from Mapbox Directions API
class RouteData {
  final List<List<double>> coordinates; // [[lng, lat], [lng, lat], ...]
  final double distanceKm;
  final int durationMinutes;

  const RouteData({
    required this.coordinates,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

/// Service for fetching routes from Mapbox Directions API
class RoutingService {
  static const profile = 'mapbox/driving-traffic';
  final String _accessToken;

  RoutingService({required String accessToken}) : _accessToken = accessToken;

  Uri buildDirectionsUri({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    final coordinates = '$fromLng,$fromLat;$toLng,$toLat';
    return Uri.https(
      'api.mapbox.com',
      '/directions/v5/$profile/$coordinates',
      {
        'geometries': 'geojson',
        'overview': 'full',
        'access_token': _accessToken,
      },
    );
  }

  /// Fetch route between two points
  /// Returns null if the request fails
  Future<RouteData?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      if (_accessToken.trim().isEmpty) return null;
      final url = buildDirectionsUri(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'];
      if (geometry is! Map<String, dynamic>) return null;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) return null;
      final distance = (route['distance'] as num).toDouble(); // meters
      final duration = (route['duration'] as num).toDouble(); // seconds

      return RouteData(
        coordinates: coords.map((raw) {
          final c = raw as List<dynamic>;
          return [(c[0] as num).toDouble(), (c[1] as num).toDouble()];
        }).toList(growable: false),
        distanceKm: distance / 1000,
        durationMinutes: (duration / 60).ceil(),
      );
    } catch (_) {
      return null;
    }
  }
}
