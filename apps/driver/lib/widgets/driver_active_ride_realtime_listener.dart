import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_resync_generation_provider.dart';
import '../providers/driver_state_provider.dart';
import '../utils/driver_rider_cancelled_flow.dart';

/// Supabase realtime backup when rider cancels during an active trip (Program 3C / L1-3).
class DriverActiveRideRealtimeListener extends ConsumerStatefulWidget {
  const DriverActiveRideRealtimeListener({super.key});

  @override
  ConsumerState<DriverActiveRideRealtimeListener> createState() =>
      _DriverActiveRideRealtimeListenerState();
}

class _DriverActiveRideRealtimeListenerState
    extends ConsumerState<DriverActiveRideRealtimeListener> {
  RealtimeChannel? _channel;
  String? _boundRideId;
  int? _resyncGen;

  void _applyResync(int gen) {
    if (_resyncGen == gen) return;
    _resyncGen = gen;
    _channel?.unsubscribe();
    _channel = null;
    _boundRideId = null;
  }

  void _syncSubscription(String? rideId) {
    if (rideId == null || rideId.isEmpty) {
      _channel?.unsubscribe();
      _channel = null;
      _boundRideId = null;
      return;
    }
    if (rideId == _boundRideId && _channel != null) return;

    _channel?.unsubscribe();
    _boundRideId = rideId;
    _channel = HeyCabySupabase.client
        .channel('ride-cancel-$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != 'cancelled' || !context.mounted) return;
            handleDriverRiderCancelled(
              ref: ref,
              context: context,
              rideId: rideId,
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyResync(ref.watch(driverResyncGenerationProvider));
    final rideId = ref.watch(driverStateProvider.select((s) => s.activeRideId));
    _syncSubscription(rideId);
    return const SizedBox.shrink();
  }
}
