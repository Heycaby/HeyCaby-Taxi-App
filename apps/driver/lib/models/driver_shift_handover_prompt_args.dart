/// Parsed notification payload for Secure Shift Handover prompt (current driver).
class DriverShiftHandoverPromptArgs {
  const DriverShiftHandoverPromptArgs({
    required this.requestId,
    this.requesterName,
    this.profilePhotoUrl,
    this.ratingStars,
    this.memberSinceYear,
    this.verified = false,
    this.plateDisplay,
    this.expiresAt,
    this.graceSeconds,
    this.title,
    this.body,
  });

  final String requestId;
  final String? requesterName;
  final String? profilePhotoUrl;
  final double? ratingStars;
  final int? memberSinceYear;
  final bool verified;
  final String? plateDisplay;
  final DateTime? expiresAt;
  final int? graceSeconds;
  final String? title;
  final String? body;

  factory DriverShiftHandoverPromptArgs.fromNotification({
    required String requestId,
    Map<String, dynamic>? data,
    String? title,
    String? body,
  }) {
    final d = data ?? const {};
    final ratingRaw = d['rating_stars'];
    double? rating;
    if (ratingRaw is num) {
      rating = ratingRaw.toDouble();
    } else if (ratingRaw is String) {
      rating = double.tryParse(ratingRaw);
    }

    final memberRaw = d['member_since'];
    int? memberSince;
    if (memberRaw is num) {
      memberSince = memberRaw.toInt();
    } else if (memberRaw is String) {
      memberSince = int.tryParse(memberRaw);
    }

    final expiresRaw = d['expires_at']?.toString();
    final graceRaw = d['grace_seconds'];

    return DriverShiftHandoverPromptArgs(
      requestId: requestId,
      requesterName: d['requester_name']?.toString(),
      profilePhotoUrl: d['profile_photo_url']?.toString(),
      ratingStars: rating,
      memberSinceYear: memberSince,
      verified: d['verified'] == true || d['verified']?.toString() == 'true',
      plateDisplay: d['plate_display']?.toString() ?? d['plate']?.toString(),
      expiresAt:
          expiresRaw != null ? DateTime.tryParse(expiresRaw)?.toUtc() : null,
      graceSeconds:
          graceRaw is num ? graceRaw.toInt() : int.tryParse('$graceRaw'),
      title: title,
      body: body,
    );
  }

  String get displayName => (requesterName ?? '').trim().isNotEmpty
      ? requesterName!.trim()
      : 'Chauffeur';

  String get starsLabel {
    final r = ratingStars;
    if (r == null || r <= 0) return '—';
    final full = r.floor().clamp(0, 5);
    final half = (r - full) >= 0.5 ? 1 : 0;
    final empty = (5 - full - half).clamp(0, 5);
    return '${'★' * full}${half > 0 ? '½' : ''}${'☆' * empty}';
  }
}
