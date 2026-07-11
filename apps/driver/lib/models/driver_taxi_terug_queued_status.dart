/// Driver's next Taxi Terug ride queued until the current trip completes.
class DriverTaxiTerugQueuedStatus {
  const DriverTaxiTerugQueuedStatus({
    required this.hasQueued,
    this.rideId,
    this.destinationLabel,
    this.pickupAddress,
    this.destinationAddress,
    this.estimatedPickupMinutes,
    this.pickupAvailableMin,
    this.pickupAvailableMax,
    this.queuedAfterRideId,
  });

  final bool hasQueued;
  final String? rideId;
  final String? destinationLabel;
  final String? pickupAddress;
  final String? destinationAddress;
  final int? estimatedPickupMinutes;
  final int? pickupAvailableMin;
  final int? pickupAvailableMax;
  final String? queuedAfterRideId;

  factory DriverTaxiTerugQueuedStatus.fromJson(Map<String, dynamic> json) {
    return DriverTaxiTerugQueuedStatus(
      hasQueued: json['has_queued'] == true,
      rideId: json['ride_id'] as String?,
      destinationLabel: json['destination_label'] as String?,
      pickupAddress: json['pickup_address'] as String?,
      destinationAddress: json['destination_address'] as String?,
      estimatedPickupMinutes:
          (json['estimated_pickup_minutes'] as num?)?.toInt(),
      pickupAvailableMin: (json['pickup_available_min'] as num?)?.toInt(),
      pickupAvailableMax: (json['pickup_available_max'] as num?)?.toInt(),
      queuedAfterRideId: json['queued_after_ride_id'] as String?,
    );
  }

  static DriverTaxiTerugQueuedStatus? parseRpc(dynamic res) {
    if (res is! Map) return null;
    final map = Map<String, dynamic>.from(res);
    return DriverTaxiTerugQueuedStatus.fromJson(map);
  }
}
