import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_resync_generation_provider.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_incoming_ride_coordinator.dart';
import '../utils/driver_rider_cancelled_flow.dart';

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
    final returnModeAsync = ref.read(driverReturnModeProvider);
    final returnModeOn = returnModeAsync.valueOrNull?.enabled == true;
    final online = appState == DriverAppState.onlineAvailable;
    final onRide = appState == DriverAppState.assigned;
    final shouldListen = online || (onRide && returnModeOn);
    if (!shouldListen || driverId == null || driverId.isEmpty) {
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
          callback: (payload) async {
            final status = payload.newRecord['status'] as String?;
            if (status != null && status != 'pending') return;
            final rideId = payload.newRecord['ride_request_id'] as String?;
            if (rideId == null || !mounted) return;
            final inviteId = payload.newRecord['id']?.toString();
            var urgent = true;
            try {
              final row = await HeyCabySupabase.client
                  .from('ride_requests')
                  .select('booking_mode')
                  .eq('id', rideId)
                  .maybeSingle();
              final bookingMode = row?['booking_mode'] as String?;
              if (bookingMode == 'terug' &&
                  ref.read(driverStateProvider).appState ==
                      DriverAppState.assigned) {
                urgent = false;
              }
            } catch (_) {}
            if (!mounted) return;
            await DriverIncomingRideCoordinator.present(
              context: context,
              ref: ref,
              rideRequestId: rideId,
              rideInviteId: inviteId,
              foreground: true,
              urgent: urgent,
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_request_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) async {
            final oldStatus = payload.oldRecord['status'] as String?;
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == null || newStatus == 'pending') return;
            if (oldStatus != null && oldStatus != 'pending') return;
            final rideId = payload.newRecord['ride_request_id'] as String?;
            if (rideId == null) return;
            stopDriverIncomingRideRinging();
            if (!mounted) return;
            if (newStatus == 'superseded') {
              try {
                final row = await HeyCabySupabase.client
                    .from('ride_requests')
                    .select('status, cancelled_by')
                    .eq('id', rideId)
                    .maybeSingle();
                if (row?['status'] == 'cancelled' && mounted) {
                  await handleDriverRiderCancelled(
                    ref: ref,
                    context: context,
                    rideId: rideId,
                  );
                }
              } catch (_) {}
              return;
            }
            try {
              final row = await HeyCabySupabase.client
                  .from('ride_requests')
                  .select('status, cancelled_by')
                  .eq('id', rideId)
                  .maybeSingle();
              if (row?['status'] == 'cancelled' &&
                  row?['cancelled_by'] == 'rider' &&
                  mounted) {
                await handleDriverRiderCancelled(
                  ref: ref,
                  context: context,
                  rideId: rideId,
                );
              }
            } catch (_) {}
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
    ref.watch(driverReturnModeProvider);
    _syncSubscription(id, appState);
    return const SizedBox.shrink();
  }
}
