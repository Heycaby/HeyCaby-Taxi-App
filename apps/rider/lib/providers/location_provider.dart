import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/rider_device_permission_snapshot.dart';
import '../services/rider_permission_backend_sync.dart';

/// Location is `null` until [requestPermissionAndStart] or [setPosition] supplies coordinates.
/// Avoids reading GPS before the user has granted permission (App Store / privacy).
class LocationNotifier extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async => null;

  Future<void> _syncPermissionState() async {
    final snap = await RiderDevicePermissionSnapshot.read();
    await RiderPermissionBackendSync.push(
      locationGranted: snap.locationGranted,
      notificationsGranted: snap.notificationsGranted,
    );
  }

  Future<void> requestPermissionAndStart() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    await _syncPermissionState();
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      state = AsyncData(
        LocationService.isInNetherlands(pos.latitude, pos.longitude)
            ? pos
            : null,
      );
    } else {
      state = const AsyncData(null);
    }
  }

  /// Refreshes location only when permission is already granted.
  /// This avoids showing OS prompts on app startup and keeps permission asks
  /// contextual to rider actions (e.g. starting a booking flow).
  Future<void> refreshIfPermitted() async {
    final perm = await Geolocator.checkPermission();
    await _syncPermissionState();
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        state = AsyncData(
          LocationService.isInNetherlands(pos.latitude, pos.longitude)
              ? pos
              : null,
        );
        return;
      } catch (_) {}
    }
    state = const AsyncData(null);
  }

  /// Set position from an external flow (e.g. splash after [LocationService.requestAndGetLocation]).
  void setPosition(Position position) {
    state = AsyncData(
      LocationService.isInNetherlands(position.latitude, position.longitude)
          ? position
          : null,
    );
  }
}

final locationProvider = AsyncNotifierProvider<LocationNotifier, Position?>(
  LocationNotifier.new,
);
