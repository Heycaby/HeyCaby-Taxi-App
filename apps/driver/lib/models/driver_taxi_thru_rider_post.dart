import 'package:flutter/foundation.dart';

@immutable
class DriverTaxiThruRiderPost {
  const DriverTaxiThruRiderPost({
    required this.id,
    required this.pickupAddress,
    required this.destinationAddress,
    this.offeredFare,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    this.pickupContactName,
    this.paymentMethods,
    this.createdAt,
    this.scheduledPickupAt,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.pickupZoneName,
    this.destinationZoneName,
    this.destinationCity,
    this.driverToPickupKm,
  });

  final String id;
  final String pickupAddress;
  final String destinationAddress;
  final double? offeredFare;
  final double? estimatedDistanceKm;
  final double? estimatedDurationMin;
  final String? pickupContactName;
  final List<String>? paymentMethods;
  final DateTime? createdAt;
  final DateTime? scheduledPickupAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final String? pickupZoneName;
  final String? destinationZoneName;
  final String? destinationCity;
  final double? driverToPickupKm;

  String get pickupLabel =>
      pickupZoneName?.isNotEmpty == true ? pickupZoneName! : pickupAddress;

  String get destinationLabel => destinationZoneName?.isNotEmpty == true
      ? destinationZoneName!
      : (destinationCity?.isNotEmpty == true
          ? destinationCity!
          : destinationAddress);

  String get fareLabel =>
      offeredFare != null ? '€${offeredFare!.toStringAsFixed(2)}' : '€—';

  String get distanceLabel => estimatedDistanceKm != null
      ? '${estimatedDistanceKm!.toStringAsFixed(1)} km'
      : '';

  String get durationLabel => estimatedDurationMin != null
      ? '${estimatedDurationMin!.toStringAsFixed(0)} min'
      : '';

  String get driverDistanceLabel => driverToPickupKm != null
      ? '${driverToPickupKm!.toStringAsFixed(1)} km away'
      : '';

  static DriverTaxiThruRiderPost? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    double? d(dynamic v) => (v as num?)?.toDouble();
    String? s(dynamic v) => v is String ? v.trim() : null;
    List<String>? pm(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }

    return DriverTaxiThruRiderPost(
      id: id,
      pickupAddress: s(j['pickup_address']) ?? '',
      destinationAddress: s(j['destination_address']) ?? '',
      offeredFare: d(j['offered_fare']),
      estimatedDistanceKm: d(j['estimated_distance_km']),
      estimatedDurationMin: d(j['estimated_duration_min']),
      pickupContactName: s(j['pickup_contact_name']),
      paymentMethods: pm(j['payment_methods']),
      createdAt: j['created_at'] is String
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      scheduledPickupAt: j['scheduled_pickup_at'] is String
          ? DateTime.tryParse(j['scheduled_pickup_at'] as String)
          : null,
      pickupLat: d(j['pickup_lat']),
      pickupLng: d(j['pickup_lng']),
      destinationLat: d(j['destination_lat']),
      destinationLng: d(j['destination_lng']),
      pickupZoneName: s(j['pickup_zone_name']),
      destinationZoneName: s(j['destination_zone_name']),
      destinationCity: s(j['destination_city']),
      driverToPickupKm: d(j['driver_to_pickup_km']),
    );
  }
}

@immutable
class DriverTaxiThruRiderPostsSnapshot {
  const DriverTaxiThruRiderPostsSnapshot({
    required this.enabled,
    required this.posts,
    this.rpcSucceeded = true,
  });

  final bool enabled;
  final List<DriverTaxiThruRiderPost> posts;
  final bool rpcSucceeded;

  static const empty = DriverTaxiThruRiderPostsSnapshot(
    enabled: false,
    posts: [],
    rpcSucceeded: false,
  );
}
