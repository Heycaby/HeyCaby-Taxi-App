import 'package:geolocator/geolocator.dart';

/// Central location permission and GPS handling for the HeyCaby rider app.
/// No location = no booking. Use before showing any map or booking flow.
class LocationService {
  LocationService._();

  /// Call on app launch — before showing the home screen map.
  /// Returns a [Position] if permission is granted, null if denied.
  static Future<Position?> requestAndGetLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  /// Netherlands bounding box — prevents simulator fake GPS (e.g. San Francisco)
  /// from being used as a real pickup address.
  /// Netherlands: lat 50.75–53.55, lng 3.31–7.23
  static bool isInNetherlands(double lat, double lng) {
    return lat >= 50.75 && lat <= 53.55 && lng >= 3.31 && lng <= 7.23;
  }
}
