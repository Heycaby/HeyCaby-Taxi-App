import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_connectivity_provider.dart';
import '../providers/driver_gps_health_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_connectivity_status.dart';
import '../services/location_service.dart';
import '../utils/driver_immersive_shell.dart';

export '../utils/driver_immersive_shell.dart';

/// Extra top inset when offline/GPS banner is shown over the map (Program 4).
final driverResilienceBannerInsetProvider = Provider<double>((ref) {
  final offline =
      ref.watch(driverConnectivityProvider) == DriverConnectivityStatus.offline;
  final tracking = shouldTrackDriverLocation(
    ref.watch(driverStateProvider).appState,
  );
  final gpsLost = tracking && !ref.watch(driverGpsHealthProvider);
  if (!offline && !gpsLost) return 0;
  return kDriverResilienceBannerBodyHeight;
});
