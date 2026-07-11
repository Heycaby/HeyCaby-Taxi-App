/// Rider-facing Taxi Terug queue state (`dispatch_state.queued_taxi_terug`).
class TaxiTerugQueueStatus {
  const TaxiTerugQueueStatus({
    required this.queuedTaxiTerug,
    required this.status,
    this.estimatedPickupMinutes,
    this.pickupAvailableMin,
    this.pickupAvailableMax,
    this.driverName,
    this.driverVehicle,
    this.driverRating,
  });

  final bool queuedTaxiTerug;
  final String status;
  final int? estimatedPickupMinutes;
  final int? pickupAvailableMin;
  final int? pickupAvailableMax;
  final String? driverName;
  final String? driverVehicle;
  final double? driverRating;

  bool get isTerugBooking => queuedTaxiTerug;

  factory TaxiTerugQueueStatus.fromJson(Map<String, dynamic> json) {
    return TaxiTerugQueueStatus(
      queuedTaxiTerug: json['queued_taxi_terug'] == true ||
          json['reserved_for_next_ride'] == true,
      status: (json['status'] as String?) ?? '',
      estimatedPickupMinutes: (json['estimated_pickup_minutes'] as num?)?.toInt(),
      pickupAvailableMin: (json['pickup_available_min'] as num?)?.toInt(),
      pickupAvailableMax: (json['pickup_available_max'] as num?)?.toInt(),
      driverName: json['driver_name'] as String?,
      driverVehicle: json['driver_vehicle'] as String?,
      driverRating: (json['driver_rating'] as num?)?.toDouble(),
    );
  }

  static TaxiTerugQueueStatus? parseRpc(dynamic res) {
    if (res is! Map) return null;
    final map = Map<String, dynamic>.from(res);
    if (map['ok'] == false) return null;
    return TaxiTerugQueueStatus.fromJson(map);
  }
}
