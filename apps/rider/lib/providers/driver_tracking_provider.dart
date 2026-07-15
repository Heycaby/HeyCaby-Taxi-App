import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DriverLocation {
  final String driverId;
  final double lat;
  final double lng;
  final double? heading;
  final DateTime updatedAt;

  const DriverLocation({
    required this.driverId,
    required this.lat,
    required this.lng,
    this.heading,
    required this.updatedAt,
  });

  Point get point => Point(coordinates: Position(lng, lat));

  /// True when lat/lng are real geographic coordinates (not (0,0) fallback).
  bool get hasValidCoords =>
      lat != 0.0 &&
      lng != 0.0 &&
      lat.abs() <= 90 &&
      lng.abs() <= 180;

  /// True when [updatedAt] is within the last [maxStaleness].
  bool isFresh({Duration maxStaleness = const Duration(seconds: 30)}) {
    final age = DateTime.now().difference(updatedAt);
    return age <= maxStaleness;
  }
}

class DriverTrackingNotifier extends AutoDisposeAsyncNotifier<DriverLocation?> {
  Timer? _pollTimer;
  String? _rideId;

  @override
  Future<DriverLocation?> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
    });
    return null;
  }

  Future<void> startTracking(String rideId) async {
    _rideId = rideId;
    await _fetchDriverLocation();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_fetchDriverLocation()),
    );
  }

  Future<void> refreshNow() async {
    await _fetchDriverLocation();
  }

  Future<void> _fetchDriverLocation() async {
    final rideId = _rideId;
    if (rideId == null || rideId.isEmpty) {
      return;
    }
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final params = <String, dynamic>{'p_ride_request_id': rideId};
      final token = identity.riderToken?.trim();
      if (token != null && token.isNotEmpty) {
        params['p_rider_token'] = token;
      }
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_driver_location_for_ride',
        params: params,
      );

      if (_rideId == null) return; // disposed / stopped while awaiting
      if (response is! Map) {
        state = const AsyncData(null);
        return;
      }
      final row = Map<String, dynamic>.from(response);
      final lat = (row['latitude'] as num).toDouble();
      final lng = (row['longitude'] as num).toDouble();
      // Reject invalid coords — no fallback, only real data.
      if (lat == 0.0 && lng == 0.0 ||
          lat.abs() > 90 || lng.abs() > 180) {
        state = const AsyncData(null);
        return;
      }
      state = AsyncData(DriverLocation(
        driverId: row['driver_id'] as String,
        lat: lat,
        lng: lng,
        heading: (row['heading'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      ));
    } catch (_) {
      if (_rideId != null) state = const AsyncData(null);
    }
  }

  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _rideId = null;
    state = const AsyncData(null);
  }
}

final driverTrackingProvider =
    AsyncNotifierProvider.autoDispose<DriverTrackingNotifier, DriverLocation?>(
  DriverTrackingNotifier.new,
);
