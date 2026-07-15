import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driver_data_providers.dart';

/// Refreshes Rider Posts (Taxi Terug browse) after realtime or accept.
void invalidateTaxiThruProviders(WidgetRef ref) {
  ref.invalidate(driverTaxiThruRiderPostsProvider);
  ref.invalidate(driverTaxiThruPostsCountProvider);
}
