/// City-level community growth stats for the Grow Your City hub.
class RiderCityCommunityStats {
  const RiderCityCommunityStats({
    required this.cityName,
    required this.driverCount,
    required this.riderCount,
    required this.memberGoal,
    this.launchCelebrationHint,
  });

  final String cityName;
  final int driverCount;
  final int riderCount;
  final int memberGoal;
  final String? launchCelebrationHint;

  int get totalMembers => driverCount + riderCount;

  double get progressFraction {
    if (memberGoal <= 0) return 0;
    return (totalMembers / memberGoal).clamp(0.0, 1.0);
  }

  int get membersRemaining =>
      (memberGoal - totalMembers).clamp(0, memberGoal);

  factory RiderCityCommunityStats.fromJson(Map<String, dynamic> json) {
    return RiderCityCommunityStats(
      cityName: (json['city_name'] ?? json['cityName'] ?? 'Rotterdam')
          .toString(),
      driverCount: (json['driver_count'] as num?)?.toInt() ??
          (json['drivers'] as num?)?.toInt() ??
          0,
      riderCount: (json['rider_count'] as num?)?.toInt() ??
          (json['riders'] as num?)?.toInt() ??
          0,
      memberGoal: (json['member_goal'] as num?)?.toInt() ??
          (json['goal'] as num?)?.toInt() ??
          10000,
      launchCelebrationHint: json['launch_celebration_hint'] as String?,
    );
  }

  static const empty = RiderCityCommunityStats(
    cityName: 'Rotterdam',
    driverCount: 0,
    riderCount: 0,
    memberGoal: 10000,
    launchCelebrationHint: null,
  );
}

/// Personal invite impact — no monetary rewards.
class RiderInviteImpact {
  const RiderInviteImpact({
    required this.peopleInvited,
    required this.joined,
    required this.completedRides,
  });

  final int peopleInvited;
  final int joined;
  final int completedRides;

  static const empty = RiderInviteImpact(
    peopleInvited: 0,
    joined: 0,
    completedRides: 0,
  );
}

enum RiderCommunityBadgeTier {
  supporter,
  builder,
  ambassador,
  topPromoter,
}

extension RiderCommunityBadgeTierX on RiderCommunityBadgeTier {
  static List<RiderCommunityBadgeTier> earnedForJoined(int joined) {
    final tiers = <RiderCommunityBadgeTier>[];
    if (joined >= 1) tiers.add(RiderCommunityBadgeTier.supporter);
    if (joined >= 5) tiers.add(RiderCommunityBadgeTier.builder);
    if (joined >= 15) tiers.add(RiderCommunityBadgeTier.ambassador);
    if (joined >= 50) tiers.add(RiderCommunityBadgeTier.topPromoter);
    return tiers;
  }
}
