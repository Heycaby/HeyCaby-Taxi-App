import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_resync_generation_provider.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';

/// When the driver is available, subscribes to [ride_request_invites] inserts for
/// this driver and opens the incoming-request screen (cascade matching).
class RideInviteRealtimeListener extends ConsumerStatefulWidget {
  const RideInviteRealtimeListener({super.key});

  @override
  ConsumerState<RideInviteRealtimeListener> createState() =>
      _RideInviteRealtimeListenerState();
}

class _RideInviteRealtimeListenerState
    extends ConsumerState<RideInviteRealtimeListener> {
  RealtimeChannel? _channel;
  String? _boundDriverId;
  int? _resyncGen;

  void _applyResync(int gen) {
    if (_resyncGen == gen) return;
    _resyncGen = gen;
    _channel?.unsubscribe();
    _channel = null;
    _boundDriverId = null;
  }

  void _syncSubscription(String? driverId, DriverAppState appState) {
    final online = appState == DriverAppState.onlineAvailable;
    if (!online || driverId == null || driverId.isEmpty) {
      _channel?.unsubscribe();
      _channel = null;
      _boundDriverId = null;
      return;
    }
    if (driverId == _boundDriverId && _channel != null) return;

    _channel?.unsubscribe();
    _boundDriverId = driverId;
    _channel = HeyCabySupabase.client
        .channel('ride-invites-$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_request_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null && status != 'pending') return;
            final rideId = payload.newRecord['ride_request_id'] as String?;
            if (rideId == null || !context.mounted) return;
            HapticService.heavyTap();
            final path = GoRouterState.of(context).uri.path;
            if (path.startsWith('/driver/ride/new/')) return;
            context.push('/driver/ride/new/$rideId');
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
    final id = ref.watch(driverIdProvider).valueOrNull;
    final appState = ref.watch(driverStateProvider).appState;
    _syncSubscription(id, appState);
    return const SizedBox.shrink();
  }
}
