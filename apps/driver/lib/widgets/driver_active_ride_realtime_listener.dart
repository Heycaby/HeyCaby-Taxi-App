import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_resync_generation_provider.dart';
import '../providers/driver_state_provider.dart';
import '../utils/driver_rider_cancelled_flow.dart';

const _kActiveRideRouteSelect =
    'status, destination_address, destination_lat, destination_lng, '
    'booked_destination_address, booked_destination_lat, booked_destination_lng, '
    'route_stops, route_revision, pending_route_change';

/// Supabase realtime backup when rider cancels during an active trip (Program 3C / L1-3).
class DriverActiveRideRealtimeListener extends ConsumerStatefulWidget {
  const DriverActiveRideRealtimeListener({super.key});

  @override
  ConsumerState<DriverActiveRideRealtimeListener> createState() =>
      _DriverActiveRideRealtimeListenerState();
}

class _DriverActiveRideRealtimeListenerState
    extends ConsumerState<DriverActiveRideRealtimeListener>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  Timer? _reconcileTimer;
  String? _boundRideId;
  int? _resyncGen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reconcileTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_reconcile()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    final rideId = _boundRideId;
    if (rideId == null || rideId.isEmpty || !mounted) return;
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(_kActiveRideRouteSelect)
          .eq('id', rideId)
          .maybeSingle();
      if (row == null || !mounted) return;
      ref.read(driverStateProvider.notifier).patchActiveRouteFromRow(
            Map<String, dynamic>.from(row),
          );
      if (row['status'] == 'cancelled' && mounted) {
        await handleDriverRiderCancelled(
          ref: ref,
          context: context,
          rideId: rideId,
        );
      }
    } catch (_) {
      // Realtime remains primary; the next reconciliation retries safely.
    }
  }

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
            final record = Map<String, dynamic>.from(payload.newRecord);
            ref.read(driverStateProvider.notifier).patchActiveRouteFromRow(
                  record,
                );
            final status = record['status'] as String?;
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
    WidgetsBinding.instance.removeObserver(this);
    _reconcileTimer?.cancel();
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
