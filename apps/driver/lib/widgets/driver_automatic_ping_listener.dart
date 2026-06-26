import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_automatic_ping_service.dart';
import '../utils/driver_ride_proximity.dart';

/// Sends automatic pings: outside at ≤150 m while en route to pickup.
class DriverAutomaticPingListener extends ConsumerStatefulWidget {
  const DriverAutomaticPingListener({super.key});

  @override
  ConsumerState<DriverAutomaticPingListener> createState() =>
      _DriverAutomaticPingListenerState();
}

class _DriverAutomaticPingListenerState
    extends ConsumerState<DriverAutomaticPingListener> {
  final _service = const DriverAutomaticPingService();
  String? _lastOutsideRideId;

  void _maybeSendOutsidePing() {
    final driver = ref.read(driverStateProvider);
    if (driver.appState != DriverAppState.assigned) return;
    final rideId = driver.activeRideId;
    if (rideId == null || rideId.isEmpty) return;
    if (_lastOutsideRideId == rideId) return;

    final pickupLat = driver.pickupLat;
    final pickupLng = driver.pickupLng;
    if (pickupLat == null || pickupLng == null) return;

    final position = ref.read(driverLocationProvider).valueOrNull;
    if (position == null) return;

    final distanceM = distanceToTargetMeters(
      lat: position.latitude,
      lng: position.longitude,
      targetLat: pickupLat,
      targetLng: pickupLng,
    );
    if (distanceM > kSmartPingOutsideRadiusM) return;

    _lastOutsideRideId = rideId;
    unawaited(
      _service.sendIfNeeded(
        rideRequestId: rideId,
        type: DriverPingType.outside,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(driverLocationProvider, (_, __) => _maybeSendOutsidePing());
    ref.listen(driverStateProvider, (_, __) => _maybeSendOutsidePing());

    return const SizedBox.shrink();
  }
}
