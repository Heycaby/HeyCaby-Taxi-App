class RideRequest {
  final String id;
  final String status;
  final String bookingMode;
  final String? riderToken;
  final String? riderIdentityId;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final String? pickupAddress;
  final String? destinationAddress;
  final String? pickupContactName;
  final List<String> paymentMethods;
  final bool favoritesFirst;
  final DateTime? scheduledPickupAt;
  final DateTime createdAt;

  const RideRequest({
    required this.id,
    required this.status,
    required this.bookingMode,
    this.riderToken,
    this.riderIdentityId,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    this.pickupAddress,
    this.destinationAddress,
    this.pickupContactName,
    required this.paymentMethods,
    required this.favoritesFirst,
    this.scheduledPickupAt,
    required this.createdAt,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'] as String,
      status: json['status'] as String,
      bookingMode: json['booking_mode'] as String? ?? 'instant',
      riderToken: json['rider_token'] as String?,
      riderIdentityId: json['rider_identity_id'] as String?,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      destinationLat: (json['destination_lat'] as num?)?.toDouble() ?? 0.0,
      destinationLng: (json['destination_lng'] as num?)?.toDouble() ?? 0.0,
      pickupAddress: json['pickup_address'] as String?,
      destinationAddress: json['destination_address'] as String?,
      pickupContactName: json['pickup_contact_name'] as String?,
      paymentMethods: List<String>.from(json['payment_methods'] as List? ?? []),
      favoritesFirst: json['favorites_first'] as bool? ??
          json['favorites_only'] as bool? ??
          false,
      scheduledPickupAt: json['scheduled_pickup_at'] != null
          ? DateTime.parse(json['scheduled_pickup_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
