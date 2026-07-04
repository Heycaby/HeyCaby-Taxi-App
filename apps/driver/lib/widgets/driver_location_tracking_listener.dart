import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_operational_restore_models.dart';
import '../services/location_service.dart';

/// Keeps [DriverLocationService] in sync with [driverStateProvider] and app lifecycle.
///
/// Program 3A: continuous GPS upload while online or on an active ride.
class DriverLocationTrackingListener extends ConsumerStatefulWidget {
  const DriverLocationTrackingListener({super.key});

  @override
  ConsumerState<DriverLocationTrackingListener> createState() =>
      _DriverLocationTrackingListenerState();
}

class _DriverLocationTrackingListenerState
    extends ConsumerState<DriverLocationTrackingListener>
    with WidgetsBindingObserver {
  DriverAppState? _lastSyncedState;
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromProvider());
    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_syncFromProvider());
      unawaited(_syncFromServerStatus());
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_onAppResumed());
    }
  }

  Future<void> _onAppResumed() async {
    await _syncFromProvider();
    await _syncFromServerStatus();
    await DriverLocationService().uploadNowIfTracking();
    if (mounted) {
      ref.invalidate(driverLocationProvider);
    }
  }

  Future<void> _syncFromProvider() async {
    final appState = ref.read(driverStateProvider).appState;
    final expectedTracking = shouldTrackDriverLocation(appState);
    final service = DriverLocationService();
    if (_lastSyncedState == appState &&
        service.isTracking == expectedTracking) {
      return;
    }
    _lastSyncedState = appState;
    await service.syncWithAppState(appState);
  }

  Future<void> _syncFromServerStatus() async {
    final localState = ref.read(driverStateProvider).appState;
    if (shouldTrackDriverLocation(localState)) return;
    if (localState == DriverAppState.assigned ||
        localState == DriverAppState.arrived ||
        localState == DriverAppState.inProgress ||
        localState == DriverAppState.completingRide) {
      return;
    }

    final driverId = await ref.read(driverIdProvider.future);
    if (driverId == null) return;

    try {
      final row = await HeyCabySupabase.client
          .from('drivers')
          .select('status')
          .eq('id', driverId)
          .maybeSingle();
      final serverState =
          driverAvailabilityFromServerStatus(row?['status'] as String?);
      if (!mounted) return;
      if (serverState != localState) {
        ref.read(driverStateProvider.notifier).setStatus(serverState);
      }
      await DriverLocationService().syncWithAppState(serverState);
    } catch (_) {
      // Best-effort watchdog only. Normal status transitions still drive tracking.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DriverData>(driverStateProvider, (previous, next) {
      if (previous?.appState == next.appState) return;
      _lastSyncedState = next.appState;
      unawaited(DriverLocationService().syncWithAppState(next.appState));
    });

    return const SizedBox.shrink();
  }
}
