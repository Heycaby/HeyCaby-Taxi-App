import 'package:flutter/foundation.dart';

@immutable
class TaxiTerugCandidate {
  const TaxiTerugCandidate({
    required this.driverName,
    this.vehicle,
    this.headingTo,
    required this.pickupEtaMinutes,
    required this.estimatedFareMin,
    required this.estimatedFareMax,
    required this.matchScore,
    this.whyMatch,
    required this.driverRating,
    this.inTransit = false,
    this.availableAfterMinutes,
    this.pickupAvailableMin,
    this.pickupAvailableMax,
    this.intentType,
    this.departureTime,
  });

  final String driverName;
  final String? vehicle;
  final String? headingTo;
  final int pickupEtaMinutes;
  final double estimatedFareMin;
  final double estimatedFareMax;
  final double matchScore;
  final String? whyMatch;
  final double driverRating;
  final bool inTransit;
  final int? availableAfterMinutes;
  final int? pickupAvailableMin;
  final int? pickupAvailableMax;
  final String? intentType;
  final DateTime? departureTime;

  bool get isPlannedDirection => intentType == 'planned_direction';
  bool get hasDepartureTime => departureTime != null;

  static TaxiTerugCandidate? fromJson(Map<String, dynamic> j) {
    final name = (j['driver_name'] as String? ?? '').trim();
    if (name.isEmpty) return null;
    double dbl(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return TaxiTerugCandidate(
      driverName: name,
      vehicle: (j['vehicle'] as String?)?.trim(),
      headingTo: (j['heading_to'] as String?)?.trim(),
      pickupEtaMinutes: (j['pickup_eta_minutes'] as num?)?.toInt() ?? 0,
      estimatedFareMin: dbl(j['estimated_fare_min']),
      estimatedFareMax: dbl(j['estimated_fare_max']),
      matchScore: dbl(j['match_score']),
      whyMatch: (j['why_match'] as String?)?.trim(),
      driverRating: dbl(j['driver_rating']),
      inTransit: j['in_transit'] == true,
      availableAfterMinutes: (j['available_after_minutes'] as num?)?.toInt(),
      pickupAvailableMin: (j['pickup_available_min'] as num?)?.toInt(),
      pickupAvailableMax: (j['pickup_available_max'] as num?)?.toInt(),
      intentType: (j['intent_type'] as String?)?.trim(),
      departureTime: j['departure_time'] is String
          ? DateTime.tryParse(j['departure_time'] as String)
          : null,
    );
  }
}

@immutable
class TaxiTerugCandidatesSnapshot {
  const TaxiTerugCandidatesSnapshot({
    required this.enabled,
    required this.candidates,
    this.tripDistanceKm,
    this.reason,
    this.rpcSucceeded = true,
  });

  final bool enabled;
  final List<TaxiTerugCandidate> candidates;
  final double? tripDistanceKm;
  final String? reason;
  final bool rpcSucceeded;

  int get candidateCount => candidates.length;

  static const empty = TaxiTerugCandidatesSnapshot(
    enabled: false,
    candidates: [],
    rpcSucceeded: false,
  );
}
