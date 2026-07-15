import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_data_providers.dart';
import 'driver_ride_line_refresh.dart';

/// Refreshes home Today card, Today screen lists, and shift stats after ride lifecycle changes.
void invalidateTodayRideProviders(WidgetRef ref) {
  ref.invalidate(todayMyRidesProvider);
  ref.invalidate(upcomingRidesProvider);
  ref.invalidate(myRidesProvider);
  ref.invalidate(todayRidesProvider);
  ref.invalidate(driverShiftStatsProvider);
  ref.invalidate(driverEarningsProvider);
  invalidateDriverRideLine(ref);
}
