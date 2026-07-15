class AddressResult {
  final String displayName;
  final String fullAddress;
  final double lat;
  final double lng;
  final String? mapboxId;
  final String? city;
  final String? country;

  const AddressResult({
    required this.displayName,
    required this.fullAddress,
    required this.lat,
    required this.lng,
    this.mapboxId,
    this.city,
    this.country,
  });

  factory AddressResult.fromJson(Map<String, dynamic> json) {
    return AddressResult(
      displayName: json['display_name'] as String? ?? '',
      fullAddress: json['full_address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      mapboxId: json['mapbox_id'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
    );
  }

  /// True when lat/lng are real geographic coordinates (not (0,0) fallback).
  bool get hasValidCoords =>
      lat != 0.0 &&
      lng != 0.0 &&
      lat.abs() <= 90 &&
      lng.abs() <= 180;

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'full_address': fullAddress,
    'lat': lat,
    'lng': lng,
    if (mapboxId != null) 'mapbox_id': mapboxId,
    if (city != null) 'city': city,
    if (country != null) 'country': country,
  };
}
