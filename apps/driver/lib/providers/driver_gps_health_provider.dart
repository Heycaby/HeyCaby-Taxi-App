import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location_service.dart';

/// True when recent GPS uploads succeed while tracking (Program 3E).
class DriverGpsHealthNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = DriverLocationService();
    service.onGpsHealthChanged = (healthy) {
      state = healthy;
    };
    ref.onDispose(() {
      service.onGpsHealthChanged = null;
    });
    return service.isGpsHealthy;
  }
}

final driverGpsHealthProvider =
    NotifierProvider<DriverGpsHealthNotifier, bool>(DriverGpsHealthNotifier.new);
