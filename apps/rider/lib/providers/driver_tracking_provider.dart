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
      const Duration(seconds: 5),
      (_) => unawaited(_fetchDriverLocation()),
    );
  }

  Future<void> _fetchDriverLocation() async {
    final rideId = _rideId;
    if (rideId == null || rideId.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    try {
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_driver_location_for_ride',
        params: {'p_ride_request_id': rideId},
      );

      if (response is! Map) {
        state = const AsyncData(null);
        return;
      }
      final row = Map<String, dynamic>.from(response);
      state = AsyncData(DriverLocation(
        driverId: row['driver_id'] as String,
        lat: (row['latitude'] as num).toDouble(),
        lng: (row['longitude'] as num).toDouble(),
        heading: (row['heading'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      ));
    } catch (e) {
      state = const AsyncData(null);
    }
  }

  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _rideId = null;
  }
}

final driverTrackingProvider =
    AsyncNotifierProvider.autoDispose<DriverTrackingNotifier, DriverLocation?>(
  DriverTrackingNotifier.new,
);
