import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Location is `null` until [requestPermissionAndStart] or [setPosition] supplies coordinates.
/// Avoids reading GPS before the user has granted permission (App Store / privacy).
class LocationNotifier extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async => null;

  Future<void> requestPermissionAndStart() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      state = AsyncData(pos);
    } else {
      state = const AsyncData(null);
    }
  }

  /// Set position from an external flow (e.g. splash after [LocationService.requestAndGetLocation]).
  void setPosition(Position position) {
    state = AsyncData(position);
  }
}

final locationProvider = AsyncNotifierProvider<LocationNotifier, Position?>(
  LocationNotifier.new,
);
