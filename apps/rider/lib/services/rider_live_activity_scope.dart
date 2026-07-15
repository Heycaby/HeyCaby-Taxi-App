import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/driver_tracking_provider.dart';
import '../providers/ride_request_provider.dart';
import 'rider_ride_lifecycle_engine.dart';
import 'rider_notify_live_activity.dart';

/// Wires Supabase realtime, polling, app lifecycle, and driver location into
/// [RiderRideLifecycleEngine] — the Live Activity is a first-class consumer of ride state.
class RiderLiveActivityScope extends ConsumerStatefulWidget {
  final Widget child;

  const RiderLiveActivityScope({super.key, required this.child});

  @override
  ConsumerState<RiderLiveActivityScope> createState() =>
      _RiderLiveActivityScopeState();
}

class _RiderLiveActivityScopeState extends ConsumerState<RiderLiveActivityScope>
    with WidgetsBindingObserver {
  RealtimeChannel? _rideChannel;
  Timer? _pollTimer;
  Timer? _graceTimer;
  String? _subscribedRideId;

  RiderRideLifecycleEngine get _engine =>
      ref.read(riderRideLifecycleEngineProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ride = ref.read(rideRequestProvider);
      _ensureRideSubscription(ride.rideRequestId);
      _ensurePollTimer(ride);
      _ensureGraceTimer();
      if (ride.rideRequestId == null || ride.rideRequestId!.isEmpty) {
        unawaited(RiderNotifyLiveActivity.reconcileNoActiveRide());
      } else {
        unawaited(_refreshFromServer(source: 'scope_init'));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _graceTimer?.cancel();
    _rideChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshFromServer(source: 'app_resumed'));
    }
  }

  void _ensurePollTimer(RideRequestState ride) {
    final id = ride.rideRequestId;
    final status = ride.status;
    final needsPoll =
        id != null && status != null && !RiderRideStatuses.isTerminal(status);
    if (!needsPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshFromServer(source: 'periodic_poll'));
    });
  }

  void _ensureGraceTimer() {
    if (!_engine.shouldRunGraceTick) {
      _graceTimer?.cancel();
      _graceTimer = null;
      return;
    }
    if (_graceTimer != null) return;
    _graceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_engine.fanOutFromCurrentState(source: 'grace_tick'));
    });
  }

  void _ensureRideSubscription(String? rideId) {
    if (rideId == null || rideId.isEmpty) {
      _rideChannel?.unsubscribe();
      _rideChannel = null;
      _subscribedRideId = null;
      return;
    }
    if (_subscribedRideId == rideId) return;
    _rideChannel?.unsubscribe();
    _subscribedRideId = rideId;
    _rideChannel = HeyCabySupabase.client
        .channel('rider_ride_lifecycle_engine:$rideId')
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
            // Always fetch full row — realtime payloads may omit unchanged columns.
            unawaited(_refreshFromServer(source: 'realtime'));
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Realtime is delivery, not truth. Fetch after every successful
        // subscription so reconnects cannot leave stale Rider state.
        unawaited(
          _refreshFromServer(source: 'realtime_subscribed'),
        );
      }
    });
  }

  Future<void> _refreshFromServer({required String source}) async {
    if (!mounted) return;
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    try {
      await _engine.refreshRideState(source: source);
      if (mounted) _ensureGraceTimer();
    } catch (_) {
      // Offline — keep last Live Activity payload.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RideRequestState>(rideRequestProvider, (prev, next) {
      if (prev?.rideRequestId != next.rideRequestId) {
        if (prev?.rideRequestId != null) {
          _engine.resetForRideChange(previousRideId: prev?.rideRequestId);
        }
        if (next.rideRequestId == null || next.rideRequestId!.isEmpty) {
          unawaited(RiderNotifyLiveActivity.reconcileNoActiveRide());
        }
        _ensureRideSubscription(next.rideRequestId);
      }
      _ensurePollTimer(next);
      _ensureGraceTimer();
      if (prev?.status != next.status) {
        unawaited(
          _engine.fanOutFromCurrentState(source: 'provider_status_change'),
        );
      }
    });

    ref.listen<AsyncValue<DriverLocation?>>(
      driverTrackingProvider,
      (prev, next) {
        final status = ref.read(rideRequestProvider).status;
        if (!RiderRideStatuses.isActive(status)) return;
        next.whenData((_) {
          unawaited(
            _engine.fanOutFromCurrentState(source: 'driver_location'),
          );
        });
      },
    );

    return widget.child;
  }
}
