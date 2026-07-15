import 'package:heycaby_map/heycaby_map.dart';

/// Premium ETA service — no fallbacks, no hardcoded speeds.
///
/// Uses Mapbox Directions API (traffic-aware) for real travel times.
/// Returns `null` when real data is unavailable. Callers must show
/// an "unavailable" state, never a fabricated estimate.
abstract final class RiderEtaService {
  static RoutingService? _routing;

  static RoutingService _routingService() {
    return _routing ??= RoutingService(
      accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    );
  }

  /// Fetch real ETA in minutes from [fromLat,fromLng] to [toLat,toLng].
  ///
  /// Returns `null` if:
  /// - coordinates are invalid (0,0, out of range)
  /// - Mapbox token is missing
  /// - network/routing request fails
  ///
  /// **Never** returns a fabricated estimate. Callers should show
  /// "ETA unavailable" or "tap to retry" when this returns null.
  static Future<int?> etaMinutes({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (!_validCoord(fromLat, fromLng) || !_validCoord(toLat, toLng)) {
      return null;
    }
    final route = await _routingService().fetchRoute(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
    if (route == null || route.durationMinutes < 1) return null;
    return route.durationMinutes.clamp(1, 240);
  }

  /// Fetch real distance in km between two points.
  ///
  /// Returns `null` if coordinates are invalid or routing fails.
  static Future<double?> distanceKm({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (!_validCoord(fromLat, fromLng) || !_validCoord(toLat, toLng)) {
      return null;
    }
    final route = await _routingService().fetchRoute(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
    return route?.distanceKm;
  }

  static bool _validCoord(double lat, double lng) =>
      lat != 0.0 &&
      lng != 0.0 &&
      lat.abs() <= 90 &&
      lng.abs() <= 180;
}
