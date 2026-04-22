import 'dart:math' as math;

import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/rider_vehicle_category.dart';

/// One driver available near pickup — carries their real pricing from the DB.
class NearbyDriverOffer {
  const NearbyDriverOffer({
    required this.driverId,
    required this.driverName,
    this.driverPhoto,
    required this.driverRating,
    required this.distanceKmPickup,
    required this.estimatedFareEuro,
    required this.baseFare,
    required this.perKmRate,
  });

  final String driverId;
  final String driverName;
  final String? driverPhoto;
  final double driverRating;
  final double distanceKmPickup;
  final double estimatedFareEuro;
  final double baseFare;
  final double perKmRate;
}

/// Supply snapshot for one vehicle category at pickup.
class CategorySupplySnapshot {
  const CategorySupplySnapshot({
    required this.category,
    required this.driverCount,
    required this.nearestDistanceKm,
    required this.fromPriceEuro,
    required this.drivers,
  });

  final RiderVehicleCategory category;
  final int driverCount;
  final double? nearestDistanceKm;
  final double? fromPriceEuro;
  final List<NearbyDriverOffer> drivers;

  static CategorySupplySnapshot empty(RiderVehicleCategory category) =>
      CategorySupplySnapshot(
        category: category,
        driverCount: 0,
        nearestDistanceKm: null,
        fromPriceEuro: null,
        drivers: const [],
      );
}

/// Loads live driver supply near pickup, joins real driver pricing + profile.
class NearbySupplyService {
  NearbySupplyService._();

  static const double searchRadiusKm = 12.0;
  static const Duration maxLocationAge = Duration(minutes: 3);

  // Fallback rates used only when a driver has no pricing set
  static const double _fallbackBase = 4.25;
  static const double _fallbackPerKm = 1.85;

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  static RiderVehicleCategory _categoryForDriver(String driverId) {
    final bucket = driverId.hashCode.abs() % RiderVehicleCategory.values.length;
    return RiderVehicleCategory.values[bucket];
  }

  static double _computeFare({
    required double tripKm,
    required double baseFare,
    required double perKmRate,
  }) {
    final raw = baseFare + tripKm * perKmRate;
    return (raw * 10).roundToDouble() / 10;
  }

  static Future<Map<RiderVehicleCategory, CategorySupplySnapshot>> loadForPickup({
    required AddressResult pickup,
    AddressResult? destination,
  }) async {
    final tripKm = destination != null
        ? distanceKm(pickup.lat, pickup.lng, destination.lat, destination.lng)
        : 2.0;

    const latDelta = searchRadiusKm / 111.0;
    final cosLat = math.max(0.35, math.cos(pickup.lat * math.pi / 180.0));
    final lngDelta = searchRadiusKm / (111.0 * cosLat);
    final now = DateTime.now().toUtc();

    // 1. Fetch nearby online driver locations
    List<dynamic> locRows;
    try {
      final res = await HeyCabySupabase.client
          .from('driver_locations')
          .select('driver_id, latitude, longitude, updated_at')
          .gte('latitude', pickup.lat - latDelta)
          .lte('latitude', pickup.lat + latDelta)
          .gte('longitude', pickup.lng - lngDelta)
          .lte('longitude', pickup.lng + lngDelta);
      locRows = res as List<dynamic>;
    } catch (_) {
      locRows = const [];
    }

    // Filter fresh locations only
    final freshByDriverId = <String, Map<String, dynamic>>{};
    for (final row in locRows) {
      final m = row as Map<String, dynamic>;
      final id = m['driver_id'] as String?;
      if (id == null) continue;
      final rawTs = m['updated_at'];
      if (rawTs is String) {
        final ts = DateTime.tryParse(rawTs)?.toUtc();
        if (ts != null && now.difference(ts) > maxLocationAge) continue;
      }
      freshByDriverId[id] = m;
    }

    if (freshByDriverId.isEmpty) {
      return {for (final c in RiderVehicleCategory.values) c: CategorySupplySnapshot.empty(c)};
    }

    // 2. Fetch driver profiles + pricing in one query
    Map<String, Map<String, dynamic>> driverById = {};
    try {
      final ids = freshByDriverId.keys.toList();
      // drivers.status is enum driver_status: available | on_ride | offline | on_break
      final res = await HeyCabySupabase.client
          .from('drivers')
          .select('id, full_name, profile_photo_url, rating, base_fare, per_km_rate, vehicle_category')
          .inFilter('id', ids)
          .inFilter('status', ['available', 'on_ride']);
      for (final row in (res as List<dynamic>)) {
        final m = row as Map<String, dynamic>;
        final id = m['id'] as String?;
        if (id != null) driverById[id] = m;
      }
    } catch (_) {}

    // 3. Build per-category offer lists
    final byCategory = <RiderVehicleCategory, List<NearbyDriverOffer>>{
      for (final c in RiderVehicleCategory.values) c: <NearbyDriverOffer>[],
    };

    for (final entry in freshByDriverId.entries) {
      final driverId = entry.key;
      final locRow = entry.value;
      final dRow = driverById[driverId];
      if (dRow == null) continue; // skip offline drivers

      final lat = (locRow['latitude'] as num?)?.toDouble();
      final lng = (locRow['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final dKm = distanceKm(pickup.lat, pickup.lng, lat, lng);
      if (dKm > searchRadiusKm) continue;

      final rawCat = dRow['vehicle_category'] as String?;
      final cat = RiderVehicleCategory.tryParse(rawCat) ?? _categoryForDriver(driverId);

      final base = (dRow['base_fare'] as num?)?.toDouble() ?? _fallbackBase;
      final perKm = (dRow['per_km_rate'] as num?)?.toDouble() ?? _fallbackPerKm;
      final fare = _computeFare(tripKm: tripKm, baseFare: base, perKmRate: perKm);

      byCategory[cat]!.add(NearbyDriverOffer(
        driverId: driverId,
        driverName: (dRow['full_name'] as String?)?.trim().isNotEmpty == true
            ? dRow['full_name'] as String
            : 'Driver',
        driverPhoto: dRow['profile_photo_url'] as String?,
        driverRating: (dRow['rating'] as num?)?.toDouble() ?? 5.0,
        distanceKmPickup: dKm,
        estimatedFareEuro: fare,
        baseFare: base,
        perKmRate: perKm,
      ));
    }

    // Sort by distance within each category
    for (final list in byCategory.values) {
      list.sort((a, b) => a.distanceKmPickup.compareTo(b.distanceKmPickup));
    }

    final out = <RiderVehicleCategory, CategorySupplySnapshot>{};
    for (final c in RiderVehicleCategory.values) {
      final list = byCategory[c]!;
      if (list.isEmpty) {
        out[c] = CategorySupplySnapshot.empty(c);
        continue;
      }
      final nearest = list.first.distanceKmPickup;
      final minFare = list.map((e) => e.estimatedFareEuro).reduce(math.min);
      out[c] = CategorySupplySnapshot(
        category: c,
        driverCount: list.length,
        nearestDistanceKm: nearest,
        fromPriceEuro: minFare,
        drivers: List.unmodifiable(list),
      );
    }
    return out;
  }
}
