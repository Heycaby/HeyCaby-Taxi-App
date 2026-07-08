import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_state_provider.dart';

const Duration kDriverLocationUploadInterval = Duration(seconds: 10);

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

/// Whether the driver app should upload GPS on an interval (Program 3A).
bool shouldTrackDriverLocation(DriverAppState appState) {
  switch (appState) {
    case DriverAppState.onlineAvailable:
    case DriverAppState.reviewingRequest:
    case DriverAppState.acceptingRide:
    case DriverAppState.assigned:
    case DriverAppState.arrived:
    case DriverAppState.inProgress:
    case DriverAppState.completingRide:
    case DriverAppState.completed:
      return true;
    case DriverAppState.offline:
    case DriverAppState.onBreak:
    case DriverAppState.loggedOut:
    case DriverAppState.onboardingIncomplete:
    case DriverAppState.goingOnline:
    case DriverAppState.errorRecovery:
      return false;
  }
}

/// Driver location tracking service
/// Updates driver GPS position to backend on the certified launch interval.
class DriverLocationService {
  static final DriverLocationService _instance =
      DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  Timer? _locationTimer;
  bool _isTracking = false;
  bool _uploadInFlight = false;
  String? _cachedDriverId; // drivers.id FK, resolved once and cached
  bool _gpsHealthy = true;
  int _consecutiveGpsFailures = 0;

  /// Notified when GPS health flips (Program 3E).
  void Function(bool healthy)? onGpsHealthChanged;

  bool get isGpsHealthy => _gpsHealthy;
  bool get isTracking => _isTracking;

  /// Align periodic uploads with [DriverAppState] (start / stop).
  Future<void> syncWithAppState(DriverAppState appState) async {
    if (shouldTrackDriverLocation(appState)) {
      await startTracking();
    } else {
      stopTracking();
    }
  }

  /// Start tracking and uploading driver location on the certified launch interval.
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
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(kDriverLocationUploadInterval, (_) {
      unawaited(_uploadLocation());
    });

    // Upload immediately on start
    await _uploadLocation();
  }

  /// Stop tracking driver location
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
    _uploadInFlight = false;
    _consecutiveGpsFailures = 0;
    _setGpsHealthy(true);
  }

  /// Call on logout so the next user does not reuse the prior drivers.id cache.
  void resetSession() {
    stopTracking();
    _cachedDriverId = null;
  }

  /// Force one upload when the app returns to foreground (if tracking is active).
  Future<void> uploadNowIfTracking() async {
    if (!_isTracking) return;
    await _uploadLocation();
  }

  /// Refresh GPS immediately before accepting a ride (accept RPC requires fresh location).
  Future<void> uploadNowForAccept() async {
    await _uploadLocation();
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

  Future<Position?> _readPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _uploadLocation() async {
    if (_uploadInFlight) return;
    _uploadInFlight = true;
    try {
      final position = await _readPosition();
      if (position == null) {
        _markGpsFailure();
        return;
      }
      _markGpsSuccess();

      final authUid = HeyCabySupabase.client.auth.currentUser?.id;
      if (authUid == null) return;

      final driverId = await _resolveDriverId();
      final heading = position.heading.isFinite && position.heading >= 0
          ? position.heading.round()
          : null;

      await HeyCabySupabase.client.from('driver_locations').upsert(
        {
          'user_id': authUid,
          'driver_id': driverId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': heading,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    } finally {
      _uploadInFlight = false;
    }
  }

  void dispose() {
    stopTracking();
  }

  void _markGpsSuccess() {
    _consecutiveGpsFailures = 0;
    _setGpsHealthy(true);
  }

  void _markGpsFailure() {
    _consecutiveGpsFailures++;
    if (_consecutiveGpsFailures >= 3) {
      _setGpsHealthy(false);
    }
  }

  void _setGpsHealthy(bool value) {
    if (_gpsHealthy == value) return;
    _gpsHealthy = value;
    onGpsHealthChanged?.call(value);
  }
}
