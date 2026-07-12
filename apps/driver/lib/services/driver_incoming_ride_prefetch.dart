/// Invite metadata prefetched before navigating to [NewRideRequestScreen].
class DriverIncomingRidePrefetch {
  const DriverIncomingRidePrefetch({
    this.inviteId,
    this.expiresAt,
    this.distanceKm,
    this.etaMinutes,
  });

  final String? inviteId;
  final DateTime? expiresAt;
  final double? distanceKm;
  final double? etaMinutes;

  static DriverIncomingRidePrefetch? fromRouteExtra(Object? extra) {
    if (extra is! Map) return null;
    final map = Map<String, dynamic>.from(extra);
    final expiresRaw = map['inviteExpiresAt']?.toString();
    final expiresAt = expiresRaw == null || expiresRaw.isEmpty
        ? null
        : DateTime.tryParse(expiresRaw)?.toUtc();
    final distanceKm = (map['inviteDistanceKm'] as num?)?.toDouble();
    final etaMinutes = (map['inviteEtaMinutes'] as num?)?.toDouble();
    final inviteId = map['inviteId']?.toString();
    if (inviteId == null &&
        expiresAt == null &&
        distanceKm == null &&
        etaMinutes == null) {
      return null;
    }
    return DriverIncomingRidePrefetch(
      inviteId: inviteId,
      expiresAt: expiresAt,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
    );
  }

  Map<String, dynamic> toRouteExtra({
    required bool urgent,
    String? inviteIdOverride,
  }) {
    return {
      'urgent': urgent,
      if (inviteIdOverride != null && inviteIdOverride.isNotEmpty)
        'inviteId': inviteIdOverride
      else if (inviteId != null && inviteId!.isNotEmpty)
        'inviteId': inviteId,
      if (expiresAt != null) 'inviteExpiresAt': expiresAt!.toIso8601String(),
      if (distanceKm != null) 'inviteDistanceKm': distanceKm,
      if (etaMinutes != null) 'inviteEtaMinutes': etaMinutes,
    };
  }
}
