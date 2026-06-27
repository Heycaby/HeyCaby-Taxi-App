/// City-level community growth stats (shared transparency block in rider + driver apps).
class DriverCityCommunityStats {
  const DriverCityCommunityStats({
    required this.cityName,
    required this.driverCount,
    required this.riderCount,
    required this.memberGoal,
  });

  final String cityName;
  final int driverCount;
  final int riderCount;
  final int memberGoal;

  int get totalMembers => driverCount + riderCount;

  double get progressFraction {
    if (memberGoal <= 0) return 0;
    return (totalMembers / memberGoal).clamp(0.0, 1.0);
  }

  int get membersRemaining =>
      (memberGoal - totalMembers).clamp(0, memberGoal);

  factory DriverCityCommunityStats.fromJson(Map<String, dynamic> json) {
    return DriverCityCommunityStats(
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
    );
  }

  static const empty = DriverCityCommunityStats(
    cityName: 'Rotterdam',
    driverCount: 0,
    riderCount: 0,
    memberGoal: 10000,
  );
}

class DriverInviteImpact {
  const DriverInviteImpact({
    required this.driversInvited,
    required this.joined,
    required this.completedRides,
  });

  final int driversInvited;
  final int joined;
  final int completedRides;

  static const empty = DriverInviteImpact(
    driversInvited: 0,
    joined: 0,
    completedRides: 0,
  );
}

enum DriverCommunityBadgeTier {
  supporter,
  builder,
  ambassador,
  topPromoter,
}

extension DriverCommunityBadgeTierX on DriverCommunityBadgeTier {
  static List<DriverCommunityBadgeTier> earnedForJoined(int joined) {
    final tiers = <DriverCommunityBadgeTier>[];
    if (joined >= 1) tiers.add(DriverCommunityBadgeTier.supporter);
    if (joined >= 5) tiers.add(DriverCommunityBadgeTier.builder);
    if (joined >= 15) tiers.add(DriverCommunityBadgeTier.ambassador);
    if (joined >= 50) tiers.add(DriverCommunityBadgeTier.topPromoter);
    return tiers;
  }
}
