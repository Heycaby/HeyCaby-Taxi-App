import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Driver's current GPS position for map centering.
class DriverLocationNotifier extends AsyncNotifier<Position> {
  @override
  Future<Position> build() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        state = AsyncData(last);
        return;
      }
      state = AsyncData(
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      state = last != null
          ? AsyncData(last)
          : const AsyncError('Location unavailable', StackTrace.empty);
    }
  }
}

final driverLocationProvider =
    AsyncNotifierProvider<DriverLocationNotifier, Position>(
  DriverLocationNotifier.new,
);
