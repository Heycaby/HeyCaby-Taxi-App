import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unread rider → driver chat messages for an active ride (`messages.is_read`).
final driverRideUnreadMessageCountProvider = NotifierProvider.autoDispose
    .family<DriverRideUnreadMessageCountNotifier, int, String>(
  DriverRideUnreadMessageCountNotifier.new,
);

class DriverRideUnreadMessageCountNotifier
    extends AutoDisposeFamilyNotifier<int, String> {
  RealtimeChannel? _subscription;

  @override
  int build(String rideId) {
    ref.onDispose(() {
      unawaited(_subscription?.unsubscribe());
      _subscription = null;
    });
    unawaited(_refresh(rideId));
    _listen(rideId);
    return 0;
  }

  Future<void> _refresh(String rideId) async {
    try {
      final rows = await HeyCabySupabase.client
          .from('messages')
          .select('id')
          .eq('ride_request_id', rideId)
          .eq('sender_type', 'rider')
          .eq('is_read', false);
      state = (rows as List).length;
    } catch (_) {
      // Keep last known count on transient errors.
    }
  }

  void _listen(String rideId) {
    try {
      unawaited(_subscription?.unsubscribe());
      _subscription = HeyCabySupabase.client
          .channel('driver-unread-messages:$rideId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'ride_request_id',
              value: rideId,
            ),
            callback: (payload) {
              final record = payload.eventType == PostgresChangeEvent.delete
                  ? payload.oldRecord
                  : payload.newRecord;
              if (record['sender_type']?.toString() != 'rider') return;
              unawaited(_refresh(rideId));
            },
          )
          .subscribe();
    } catch (_) {
      // Keep last known count when realtime is unavailable.
    }
  }

  /// Call when the driver opens the full ride chat screen.
  Future<void> markAllRead() async {
    final rideId = arg;
    try {
      await HeyCabySupabase.client
          .from('messages')
          .update({'is_read': true})
          .eq('ride_request_id', rideId)
          .eq('sender_type', 'rider')
          .eq('is_read', false);
      state = 0;
    } catch (_) {
      await _refresh(rideId);
    }
  }
}
