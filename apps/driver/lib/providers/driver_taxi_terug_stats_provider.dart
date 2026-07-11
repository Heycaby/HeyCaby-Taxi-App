import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_taxi_terug_stats.dart';
import 'driver_data_providers.dart';

final driverTaxiTerugStatsProvider =
    FutureProvider<DriverTaxiTerugStats?>((ref) async {
  return ref.read(driverDataServiceProvider).fetchTaxiTerugStats();
});
