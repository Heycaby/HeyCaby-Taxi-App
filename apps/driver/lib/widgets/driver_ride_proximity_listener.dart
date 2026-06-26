import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_location_provider.dart';
import '../providers/driver_ride_proximity_provider.dart';
import '../providers/driver_state_provider.dart';

/// Refreshes GPS for proximity assist while en route or in trip (Program 3D / L2).
class DriverRideProximityListener extends ConsumerStatefulWidget {
  const DriverRideProximityListener({super.key});

  @override
  ConsumerState<DriverRideProximityListener> createState() =>
      _DriverRideProximityListenerState();
}

class _DriverRideProximityListenerState
    extends ConsumerState<DriverRideProximityListener> {
  Timer? _refreshTimer;

  bool _needsProximityRefresh(DriverAppState appState) {
    return appState == DriverAppState.assigned ||
        appState == DriverAppState.inProgress;
  }

  void _syncTimer(DriverAppState appState) {
    if (!_needsProximityRefresh(appState)) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.read(driverLocationProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(driverStateProvider).appState;
    _syncTimer(appState);

    ref.listen<DriverRideProximityAssist>(driverRideProximityProvider,
        (previous, next) {
      if (next == DriverRideProximityAssist.none) return;
      if (previous == next) return;
      HapticService.mediumTap();
    });

    return const SizedBox.shrink();
  }
}
