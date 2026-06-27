import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Grow Your City stats from [fn_community_growth_stats].
Future<CommunityGrowthStats?> fetchCommunityGrowthStats(
  SupabaseClient client, {
  String regionName = 'Netherlands',
}) async {
  try {
    final raw = await client.rpc(
      'fn_community_growth_stats',
      params: {'p_city_name': regionName},
    );
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = raw.cast<String, dynamic>();
    } else if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) map = decoded.cast<String, dynamic>();
    }
    if (map != null && map.isNotEmpty) {
      return CommunityGrowthStats.fromJson(map);
    }
  } catch (_) {}
  return null;
}

/// Backend-driven community growth + dynamic milestones (monthly riders → 1M).
class CommunityGrowthStats {
  const CommunityGrowthStats({
    required this.regionName,
    required this.driverCount,
    required this.riderCount,
    required this.monthlyDriverCount,
    required this.monthlyRiderCount,
    required this.driverCap,
    required this.riderCap,
    required this.previousMilestone,
    required this.nextMilestone,
    required this.remainingToMilestone,
    required this.progressFraction,
    required this.finalGoalReached,
    required this.achievedMilestones,
    required this.latestAchievedMilestone,
    this.milestoneJustReached,
  });

  final String regionName;
  final int driverCount;
  final int riderCount;
  final int monthlyDriverCount;
  final int monthlyRiderCount;
  final int driverCap;
  final int riderCap;
  final int previousMilestone;
  final int nextMilestone;
  final int remainingToMilestone;
  final double progressFraction;
  final bool finalGoalReached;
  final List<int> achievedMilestones;
  final int latestAchievedMilestone;
  final int? milestoneJustReached;

  int get milestoneProgressCount => monthlyRiderCount;

  factory CommunityGrowthStats.fromJson(Map<String, dynamic> json) {
    final achievedRaw = json['achieved_milestones'];
    final achieved = <int>[];
    if (achievedRaw is List) {
      for (final item in achievedRaw) {
        if (item is num) achieved.add(item.toInt());
      }
    }

    int? justReached;
    final justRaw = json['milestone_just_reached'];
    if (justRaw is num) justReached = justRaw.toInt();

    return CommunityGrowthStats(
      regionName: (json['region_name'] ?? json['city_name'] ?? 'Netherlands')
          .toString(),
      driverCount: (json['driver_count'] as num?)?.toInt() ?? 0,
      riderCount: (json['rider_count'] as num?)?.toInt() ?? 0,
      monthlyDriverCount:
          (json['monthly_driver_count'] as num?)?.toInt() ?? 0,
      monthlyRiderCount: (json['monthly_rider_count'] as num?)?.toInt() ?? 0,
      driverCap: (json['driver_cap'] as num?)?.toInt() ?? 10000,
      riderCap: (json['rider_cap'] as num?)?.toInt() ?? 1000000,
      previousMilestone:
          (json['previous_milestone'] as num?)?.toInt() ?? 0,
      nextMilestone: (json['next_milestone'] as num?)?.toInt() ?? 1000,
      remainingToMilestone:
          (json['remaining_to_milestone'] as num?)?.toInt() ?? 1000,
      progressFraction:
          (json['progress_fraction'] as num?)?.toDouble() ?? 0,
      finalGoalReached: json['final_goal_reached'] == true,
      achievedMilestones: achieved,
      latestAchievedMilestone:
          (json['latest_achieved_milestone'] as num?)?.toInt() ?? 0,
      milestoneJustReached: justReached,
    );
  }

  static const empty = CommunityGrowthStats(
    regionName: 'Netherlands',
    driverCount: 0,
    riderCount: 0,
    monthlyDriverCount: 0,
    monthlyRiderCount: 0,
    driverCap: 10000,
    riderCap: 1000000,
    previousMilestone: 0,
    nextMilestone: 1000,
    remainingToMilestone: 1000,
    progressFraction: 0,
    finalGoalReached: false,
    achievedMilestones: [],
    latestAchievedMilestone: 0,
  );
}

String formatCommunityCount(int n) {
  if (n >= 1000000) {
    final m = n / 1000000;
    return m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    final k = n / 1000;
    return k >= 10 ? '${k.toStringAsFixed(0)}k' : '${k.toStringAsFixed(1)}k';
  }
  return '$n';
}
