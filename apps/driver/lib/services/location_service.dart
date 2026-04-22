import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Request location permission and get current position.
/// Returns null if permission denied or location unavailable.
/// Use on app open — driver cannot use the app without location.
Future<Position?> requestAndGetLocation() async {
  try {
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
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      // Fallback: use last known position (e.g. simulator, or GPS not ready)
      return await Geolocator.getLastKnownPosition();
    }
  } catch (_) {
    // Missing Info.plist keys, permission denied, or GPS error — treat as unavailable
    return null;
  }
}

/// Driver location tracking service
/// Updates driver GPS position to backend every 5 seconds when online
class DriverLocationService {
  static final DriverLocationService _instance = DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  Timer? _locationTimer;
  bool _isTracking = false;
  String? _cachedDriverId; // drivers.id FK, resolved once and cached

  bool get isTracking => _isTracking;

  /// Start tracking and uploading driver location every 5 seconds
  Future<void> startTracking() async {
    if (_isTracking) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        debugPrint('DriverLocationService: Location permission denied');
      }
      return;
    }

    _isTracking = true;
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _uploadLocation();
    });

    // Upload immediately on start
    await _uploadLocation();
  }

  /// Stop tracking driver location
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
  }

  /// Resolve drivers.id from auth uid (cached after first call)
  Future<String?> _resolveDriverId() async {
    if (_cachedDriverId != null) return _cachedDriverId;
    final authUid = HeyCabySupabase.client.auth.currentUser?.id;
    if (authUid == null) return null;
    try {
      final row = await HeyCabySupabase.client
          .from('drivers')
          .select('id')
          .eq('user_id', authUid)
          .maybeSingle();
      _cachedDriverId = row?['id'] as String?;
    } catch (_) {}
    return _cachedDriverId;
  }

  Future<void> _uploadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final authUid = HeyCabySupabase.client.auth.currentUser?.id;
      if (authUid == null) return;

      final driverId = await _resolveDriverId();

      await HeyCabySupabase.client.from('driver_locations').upsert(
        {
          'user_id': authUid,
          'driver_id': driverId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      if (kDebugMode) {
        debugPrint(
            'DriverLocationService: Updated location (${position.latitude}, ${position.longitude})');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DriverLocationService: Failed to upload location - $e');
      }
    }
  }

  void dispose() {
    stopTracking();
  }
}
