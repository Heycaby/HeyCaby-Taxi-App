import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  RealtimeChannel? _subscription;

  @override
  Future<DriverLocation?> build() async {
    ref.onDispose(() {
      _subscription?.unsubscribe();
    });
    return null;
  }

  Future<void> startTracking(String rideId) async {
    // Resolve the driver_id from the ride request
    final rideRow = await HeyCabySupabase.client
        .from('ride_requests')
        .select('driver_id')
        .eq('id', rideId)
        .maybeSingle();

    final driverId = rideRow?['driver_id'] as String?;
    if (driverId == null) {
      state = const AsyncData(null);
      return;
    }

    // Fetch initial location
    await _fetchDriverLocation(driverId);

    // Subscribe to real-time updates filtered by driver_id
    _subscription = HeyCabySupabase.client
        .channel('driver_location:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            state = AsyncData(DriverLocation(
              driverId: record['driver_id'] as String,
              lat: (record['latitude'] as num).toDouble(),
              lng: (record['longitude'] as num).toDouble(),
              heading: (record['heading'] as num?)?.toDouble(),
              updatedAt: DateTime.parse(record['updated_at'] as String),
            ));
          },
        )
        .subscribe();
  }

  Future<void> _fetchDriverLocation(String driverId) async {
    try {
      final response = await HeyCabySupabase.client
          .from('driver_locations')
          .select()
          .eq('driver_id', driverId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        state = const AsyncData(null);
        return;
      }
      state = AsyncData(DriverLocation(
        driverId: response['driver_id'] as String,
        lat: (response['latitude'] as num).toDouble(),
        lng: (response['longitude'] as num).toDouble(),
        heading: (response['heading'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(response['updated_at'] as String),
      ));
    } catch (e) {
      state = const AsyncData(null);
    }
  }

  void stopTracking() {
    _subscription?.unsubscribe();
    _subscription = null;
  }
}

final driverTrackingProvider =
    AsyncNotifierProvider.autoDispose<DriverTrackingNotifier, DriverLocation?>(
  DriverTrackingNotifier.new,
);
