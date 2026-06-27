import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/driver_community_growth_models.dart';

/// Prefer [communityGrowthStatsProvider] from `heycaby_api`.
@Deprecated('Use communityGrowthStatsProvider from heycaby_api')
final driverCityCommunityStatsProvider = communityGrowthStatsProvider;

/// Driver invite impact — backend attribution can extend this later.
final driverInviteImpactProvider =
    FutureProvider.autoDispose<DriverInviteImpact>((ref) async {
  return DriverInviteImpact.empty;
});
