import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/src/community_growth_stats.dart';
import 'package:heycaby_api/src/supabase_client.dart';

/// Shared Grow Your City stats for rider and driver apps.
final communityGrowthStatsProvider =
    FutureProvider.autoDispose<CommunityGrowthStats>((ref) async {
  return await fetchCommunityGrowthStats(HeyCabySupabase.client) ??
      CommunityGrowthStats.empty;
});
