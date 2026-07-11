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

  int threshold() => switch (this) {
        RiderCommunityBadgeTier.supporter => 1,
        RiderCommunityBadgeTier.builder => 5,
        RiderCommunityBadgeTier.ambassador => 15,
        RiderCommunityBadgeTier.topPromoter => 50,
      };

  static RiderCommunityBadgeTier? nextUnearned(int joined) {
    for (final tier in RiderCommunityBadgeTier.values) {
      if (joined < tier.threshold()) return tier;
    }
    return null;
  }
}

enum RiderRideBadgeTier {
  firstRide,
  regular,
  dedicated,
  legend,
}

extension RiderRideBadgeTierX on RiderRideBadgeTier {
  int threshold() => switch (this) {
        RiderRideBadgeTier.firstRide => 1,
        RiderRideBadgeTier.regular => 10,
        RiderRideBadgeTier.dedicated => 50,
        RiderRideBadgeTier.legend => 100,
      };

  static List<RiderRideBadgeTier> earnedForRides(int rides) {
    final tiers = <RiderRideBadgeTier>[];
    if (rides >= 1) tiers.add(RiderRideBadgeTier.firstRide);
    if (rides >= 10) tiers.add(RiderRideBadgeTier.regular);
    if (rides >= 50) tiers.add(RiderRideBadgeTier.dedicated);
    if (rides >= 100) tiers.add(RiderRideBadgeTier.legend);
    return tiers;
  }

  static RiderRideBadgeTier? nextUnearned(int rides) {
    for (final tier in RiderRideBadgeTier.values) {
      if (rides < tier.threshold()) return tier;
    }
    return null;
  }
}

class RiderRideMilestones {
  const RiderRideMilestones({required this.totalCompletedRides});

  final int totalCompletedRides;

  factory RiderRideMilestones.fromJson(Map<String, dynamic> json) {
    return RiderRideMilestones(
      totalCompletedRides: (json['total_completed_rides'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = RiderRideMilestones(totalCompletedRides: 0);
}

class RiderStreak {
  const RiderStreak({required this.weekCount, required this.lastRideWeek});

  final int weekCount;
  final String lastRideWeek;

  bool get isActive => weekCount > 0;

  static const empty = RiderStreak(weekCount: 0, lastRideWeek: '');
}
