import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Records GPS breadcrumbs during an in_progress ride for actual distance
/// calculation and fare recalculation on trip completion.
///
/// Breadcrumbs are buffered locally and flushed to Supabase in batches
/// every 30 seconds via `fn_insert_ride_gps_batch` RPC.
///
/// The existing [DriverLocationService] continues to handle real-time
/// driver location updates (for rider map display). This service is
/// purely for trip distance recording.
class RideGpsTracker {
  static final RideGpsTracker _instance = RideGpsTracker._internal();
  factory RideGpsTracker() => _instance;
  RideGpsTracker._internal();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;

  String? _rideId;
  bool _isTracking = false;

  /// Buffer of GPS points waiting to be flushed to the backend.
  final List<Map<String, dynamic>> _buffer = [];

  /// Minimum distance between consecutive GPS points (meters).
  /// Filters out GPS noise when stationary.
  static const double _minDistanceMeters = 10.0;

  /// Flush interval — upload buffered GPS points every 30 seconds.
  static const Duration _flushInterval = Duration(seconds: 30);

  /// Maximum buffer size before forced flush.
  static const int _maxBufferSize = 100;

  Position? _lastRecordedPosition;

  bool get isTracking => _isTracking;

  /// Start recording GPS breadcrumbs for a ride.
  /// Called when the driver taps "Start trip" (status → in_progress).
  Future<void> startTracking(String rideId) async {
    if (_isTracking) {
      if (_rideId == rideId) return;
      // Different ride — stop previous, start new.
      await stopTracking();
    }

    _rideId = rideId;
    _isTracking = true;
    _buffer.clear();
    _lastRecordedPosition = null;

    // Use high-accuracy stream with automotive activity type.
    final settings = defaultTargetPlatform == TargetPlatform.iOS
        ? AppleSettings(
            accuracy: LocationAccuracy.best,
            activityType: ActivityType.automotiveNavigation,
            distanceFilter: 10, // 10m minimum between points
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10,
          );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) => _onPositionUpdate(position),
      onError: (e) {
        if (kDebugMode) {
          debugPrint('RideGpsTracker: position stream error — $e');
        }
      },
    );

    // Periodic flush timer.
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flushBuffer());

    if (kDebugMode) {
      debugPrint('RideGpsTracker: started tracking ride $rideId');
    }
  }

  /// Stop recording and flush any remaining buffered points.
  /// Called when the driver taps "Complete trip" (status → completed).
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Final flush — upload any remaining buffered points.
    await _flushBuffer();

    _rideId = null;
    _lastRecordedPosition = null;

    if (kDebugMode) {
      debugPrint('RideGpsTracker: stopped tracking');
    }
  }

  void _onPositionUpdate(Position position) {
    if (!_isTracking || _rideId == null) return;

    // Filter GPS noise: skip if too close to last recorded point.
    if (_lastRecordedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastRecordedPosition!.latitude,
        _lastRecordedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < _minDistanceMeters) return;
    }

    // Filter impossible jumps (> 500m in one update = GPS glitch).
    if (_lastRecordedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastRecordedPosition!.latitude,
        _lastRecordedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance > 500) {
        if (kDebugMode) {
          debugPrint(
              'RideGpsTracker: rejecting GPS jump of ${distance.round()}m');
        }
        return;
      }
    }

    _lastRecordedPosition = position;

    _buffer.add({
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading.isFinite && position.heading >= 0
          ? position.heading.toString()
          : '',
      'speed': position.speed.isFinite && position.speed >= 0
          ? position.speed.toString()
          : '',
      'accuracy': position.accuracy.isFinite && position.accuracy >= 0
          ? position.accuracy.toString()
          : '',
      'recorded_at': position.timestamp.toUtc().toIso8601String(),
    });

    // Force flush if buffer is getting large.
    if (_buffer.length >= _maxBufferSize) {
      unawaited(_flushBuffer());
    }
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty || _rideId == null) return;

    // Copy and clear buffer atomically.
    final points = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      await HeyCabySupabase.client.rpc(
        'fn_insert_ride_gps_batch',
        params: {
          'p_ride_request_id': _rideId,
          'p_points': jsonEncode(points),
        },
      );

      if (kDebugMode) {
        debugPrint('RideGpsTracker: flushed ${points.length} GPS points');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RideGpsTracker: flush failed — $e');
      }
      // Re-add points to buffer for retry on next flush.
      _buffer.insertAll(0, points);
    }
  }

  /// Flushes the current evidence batch before a completion request while
  /// keeping the tracker active if the backend moves the ride to review.
  Future<void> flush() => _flushBuffer();

  void dispose() {
    unawaited(stopTracking());
  }
}
