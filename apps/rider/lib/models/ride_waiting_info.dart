/// Rider-side waiting fee state parsed from `ride_requests` (Supabase).
class RideWaitingInfo {
  const RideWaitingInfo({
    required this.arrivedAt,
    required this.graceSeconds,
    required this.ratePerMinute,
    required this.frozenChargeableSeconds,
    required this.frozenFeeCents,
    required this.waived,
  });

  final DateTime arrivedAt;
  final int graceSeconds;
  final double ratePerMinute;
  final int frozenChargeableSeconds;
  final int frozenFeeCents;
  final bool waived;

  static RideWaitingInfo? fromJson(Map<String, dynamic> json) {
    final arrivedRaw = json['driver_arrived_at']?.toString();
    final arrivedAt = arrivedRaw == null ? null : DateTime.tryParse(arrivedRaw);
    if (arrivedAt == null) return null;
    final graceRaw = json['waiting_grace_seconds'];
    final rateRaw = json['waiting_rate_per_minute'];
    final chargeableRaw = json['chargeable_wait_seconds'];
    final feeRaw = json['waiting_fee_cents'];
    return RideWaitingInfo(
      arrivedAt: arrivedAt.toUtc(),
      graceSeconds:
          graceRaw is num ? graceRaw.toInt().clamp(0, 3600).toInt() : 120,
      ratePerMinute:
          rateRaw is num ? rateRaw.toDouble().clamp(0, 9999).toDouble() : 0,
      frozenChargeableSeconds: chargeableRaw is num
          ? chargeableRaw.toInt().clamp(0, 86400).toInt()
          : 0,
      frozenFeeCents:
          feeRaw is num ? feeRaw.toInt().clamp(0, 99999999).toInt() : 0,
      waived: json['waiting_fee_waived'] == true,
    );
  }

  int elapsedSinceArrivalSeconds({DateTime? now}) {
    final end = (now ?? DateTime.now()).toUtc();
    final seconds = end.difference(arrivedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  int remainingGraceSecondsNow() {
    final remaining = graceSeconds - elapsedSinceArrivalSeconds();
    return remaining < 0 ? 0 : remaining;
  }

  int chargeableSecondsNow() {
    if (frozenChargeableSeconds > 0) return frozenChargeableSeconds;
    final chargeable = elapsedSinceArrivalSeconds() - graceSeconds;
    return chargeable < 0 ? 0 : chargeable;
  }

  /// Matches Supabase `fn_driver_start_trip` waiting fee formula.
  int waitingFeeCentsNow() {
    if (waived) return 0;
    if (frozenFeeCents > 0) return frozenFeeCents;
    return ((chargeableSecondsNow() / 60) * ratePerMinute * 100).round();
  }

  int resolveBaseFareCents({
    required double? quotedFareEuro,
    int? liveFareCents,
  }) {
    if (frozenFeeCents > 0 && liveFareCents != null) {
      final base = liveFareCents - frozenFeeCents;
      if (base > 0) return base;
    }
    if (quotedFareEuro != null && quotedFareEuro > 0) {
      return (quotedFareEuro * 100).round();
    }
    if (liveFareCents != null && liveFareCents > 0) {
      final withoutWait = liveFareCents - waitingFeeCentsNow();
      if (withoutWait > 0) return withoutWait;
      return liveFareCents;
    }
    return 0;
  }

  int totalFareCentsNow({
    required double? quotedFareEuro,
    int? liveFareCents,
  }) {
    final base = resolveBaseFareCents(
      quotedFareEuro: quotedFareEuro,
      liveFareCents: liveFareCents,
    );
    return base + waitingFeeCentsNow();
  }

  bool get isInGracePeriod => !waived && chargeableSecondsNow() == 0;
}
