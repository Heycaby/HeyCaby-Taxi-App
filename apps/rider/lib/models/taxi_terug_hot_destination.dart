import 'package:flutter/foundation.dart';
import 'package:heycaby_models/heycaby_models.dart';

@immutable
class TaxiTerugHotDestination {
  const TaxiTerugHotDestination({
    required this.city,
    required this.lat,
    required this.lng,
    required this.driverCount,
  });

  final String city;
  final double lat;
  final double lng;
  final int driverCount;

  AddressResult toAddressResult() => AddressResult(
        displayName: city,
        fullAddress: '$city, Netherlands',
        lat: lat,
        lng: lng,
        city: city,
        country: 'NL',
      );

  static TaxiTerugHotDestination? fromJson(Map<String, dynamic> json) {
    final city = (json['city'] as String? ?? '').trim();
    if (city.isEmpty) return null;
    return TaxiTerugHotDestination(
      city: city,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      driverCount: (json['driver_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Default NL hot cities — coordinates are city-centre approximations.
const kTaxiTerugNlHotCities = <TaxiTerugHotDestination>[
  TaxiTerugHotDestination(
    city: 'Amsterdam',
    lat: 52.3676,
    lng: 4.9041,
    driverCount: 0,
  ),
  TaxiTerugHotDestination(
    city: 'Rotterdam',
    lat: 51.9244,
    lng: 4.4777,
    driverCount: 0,
  ),
  TaxiTerugHotDestination(
    city: 'Utrecht',
    lat: 52.0907,
    lng: 5.1214,
    driverCount: 0,
  ),
  TaxiTerugHotDestination(
    city: 'Den Haag',
    lat: 52.0705,
    lng: 4.3007,
    driverCount: 0,
  ),
];
