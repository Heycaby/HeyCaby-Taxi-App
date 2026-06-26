import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromProvider());
  }

  @override
  void dispose() {
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
    await DriverLocationService().uploadNowIfTracking();
    if (mounted) {
      ref.invalidate(driverLocationProvider);
    }
  }

  Future<void> _syncFromProvider() async {
    final appState = ref.read(driverStateProvider).appState;
    if (_lastSyncedState == appState) return;
    _lastSyncedState = appState;
    await DriverLocationService().syncWithAppState(appState);
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
