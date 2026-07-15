import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_ride_line_provider.dart';
import '../providers/driver_taxi_terug_queued_provider.dart';

/// Refreshes ride line + missed opportunity surfaces after lifecycle changes.
void invalidateDriverRideLine(WidgetRef ref) {
  ref.invalidate(driverRideLineProvider);
  ref.invalidate(driverMissedSummaryProvider);
  ref.invalidate(driverMissedOpportunitiesProvider);
  ref.invalidate(driverTaxiTerugQueuedProvider);
}
