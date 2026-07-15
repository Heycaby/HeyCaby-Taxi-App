import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_resync_generation_provider.dart';
import '../utils/driver_taxi_thru_refresh.dart';
import '../utils/driver_today_rides_refresh.dart';

/// Owns Driver board refresh delivery for Scheduled, Today, and Taxi Terug.
///
/// Realtime is only an invalidation signal. Every callback re-fetches the
/// canonical backend projection through its Riverpod provider.
class DriverScheduledRidesRealtimeListener extends ConsumerStatefulWidget {
  const DriverScheduledRidesRealtimeListener({super.key});

  @override
  ConsumerState<DriverScheduledRidesRealtimeListener> createState() =>
      _DriverScheduledRidesRealtimeListenerState();
}

class _DriverScheduledRidesRealtimeListenerState
    extends ConsumerState<DriverScheduledRidesRealtimeListener> {
  RealtimeChannel? _channel;
  String? _boundUserId;
  String? _boundDriverId;
  int? _resyncGen;

  void _refreshScheduledBoard() {
    ref.invalidate(scheduledRidesCountProvider);
    ref.invalidate(scheduledRidesProvider);
    ref.invalidate(scheduledRidesByTabProvider);
    ref.invalidate(feasibleScheduledCountProvider);
  }

  void _refreshTodayBoard() {
    invalidateTodayRideProviders(ref);
  }

  void _refreshTaxiThruBoard() {
    invalidateTaxiThruProviders(ref);
  }

  static bool _touchesScheduledBoard(Map<String, dynamic>? record) {
    if (record == null || record.isEmpty) return false;
    final mode = record['booking_mode']?.toString();
    if (mode == 'scheduled') return true;
    if (record['is_scheduled'] == true) return true;

    final status = record['status']?.toString();
    final driverId = record['driver_id']?.toString();
    final scheduledAt = record['scheduled_pickup_at'];
    if (driverId != null &&
        driverId.isNotEmpty &&
        scheduledAt != null &&
        (status == 'accepted' || status == 'driver_arrived')) {
      return true;
    }
    return false;
  }

  static bool _touchesTodayBoard(
    Map<String, dynamic>? record,
    String? driverId,
  ) {
    if (record == null || record.isEmpty || driverId == null) return false;
    return record['driver_id']?.toString() == driverId;
  }

  static bool _touchesTaxiThruBoard(Map<String, dynamic>? record) {
    if (record == null || record.isEmpty) return false;
    if (record['booking_mode']?.toString() != 'terug') return false;
    final status = record['status']?.toString();
    if (status == 'pending') return true;
    final driverId = record['driver_id']?.toString();
    return driverId != null &&
        driverId.isNotEmpty &&
        (status == 'accepted' || status == 'cancelled');
  }

  void _applyResync(int gen) {
    if (_resyncGen == gen) return;
    _resyncGen = gen;
    _channel?.unsubscribe();
    _channel = null;
    _boundUserId = null;
    _boundDriverId = null;
  }

  void _bind(String? userId, String? driverId) {
    if (userId == null || userId.isEmpty) {
      _channel?.unsubscribe();
      _channel = null;
      _boundUserId = null;
      _boundDriverId = null;
      return;
    }
    if (userId == _boundUserId &&
        driverId == _boundDriverId &&
        _channel != null) {
      return;
    }

    _channel?.unsubscribe();
    _boundUserId = userId;
    _boundDriverId = driverId;

    var channel = HeyCabySupabase.client
        .channel('driver-ride-board-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_requests',
          callback: (payload) {
            final touchesScheduled =
                _touchesScheduledBoard(payload.newRecord) ||
                    _touchesScheduledBoard(payload.oldRecord);
            if (touchesScheduled) {
              _refreshScheduledBoard();
            }

            final touchesToday =
                _touchesTodayBoard(payload.newRecord, driverId) ||
                    _touchesTodayBoard(payload.oldRecord, driverId);
            if (touchesToday) {
              _refreshTodayBoard();
            }

            final touchesTaxiThru = _touchesTaxiThruBoard(payload.newRecord) ||
                _touchesTaxiThruBoard(payload.oldRecord);
            if (touchesTaxiThru) {
              _refreshTaxiThruBoard();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final oldZone = payload.oldRecord['current_zone_id']?.toString();
            final newZone = payload.newRecord['current_zone_id']?.toString();
            if (oldZone != newZone) {
              ref.invalidate(currentZoneIdProvider);
              ref.invalidate(currentZoneNameProvider);
              _refreshScheduledBoard();
            }
          },
        );

    if (driverId != null && driverId.isNotEmpty) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'drivers',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: driverId,
        ),
        callback: (payload) {
          final oldCount = payload.oldRecord['shift_rides_today'];
          final newCount = payload.newRecord['shift_rides_today'];
          if (oldCount != newCount) {
            _refreshTodayBoard();
          }
        },
      );
    }

    _channel = channel.subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyResync(ref.watch(driverResyncGenerationProvider));
    final userId = HeyCabySupabase.client.auth.currentUser?.id;
    final driverId = ref.watch(driverIdProvider).valueOrNull;
    _bind(userId, driverId);
    return const SizedBox.shrink();
  }
}
