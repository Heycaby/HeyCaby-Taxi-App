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
  final String _accessToken;

  RoutingService({required String accessToken}) : _accessToken = accessToken;

  /// Fetch route between two points
  /// Returns null if the request fails
  Future<RouteData?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '$fromLng,$fromLat;$toLng,$toLat'
        '?geometries=geojson&overview=full&access_token=$_accessToken',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final distance = (route['distance'] as num).toDouble(); // meters
      final duration = (route['duration'] as num).toDouble(); // seconds

      return RouteData(
        coordinates: coords
            .map((c) => [(c as List<dynamic>)[0] as double, c[1] as double])
            .toList(),
        distanceKm: distance / 1000,
        durationMinutes: (duration / 60).ceil(),
      );
    } catch (_) {
      return null;
    }
  }
}
