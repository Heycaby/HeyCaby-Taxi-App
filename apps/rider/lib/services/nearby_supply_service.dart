import 'dart:math' as math;
import 'dart:ui';

import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/rider_vehicle_category.dart';
import 'rider_runtime_config_service.dart';

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
    this.returnDiscountPct = 0,
  });

  final String driverId;
  final String driverName;
  final String? driverPhoto;
  final double driverRating;
  final double distanceKmPickup;
  final double estimatedFareEuro;
  final double baseFare;
  final double perKmRate;

  /// Active profile return-trip discount mirrored on `drivers.active_return_discount_pct` (0–40).
  final double returnDiscountPct;
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
  static String _fallbackDriverLabel() {
    final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    if (code == 'ar') return 'السائق';
    if (code == 'nl') return 'Chauffeur';
    return 'Driver';
  }

  NearbySupplyService._();

  static double get searchRadiusKm =>
      riderRuntimeConfig.current.maxSearchRadiusKm;
  static Duration get maxLocationAge =>
      Duration(minutes: riderRuntimeConfig.current.driverLocationMaxAgeMinutes);

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

  /// Applies a driver's active return-trip discount % to an already-rounded heuristic fare.
  static double applyReturnTripDiscountToFare(
      double fareEuro, double discountPct) {
    if (discountPct <= 0) return fareEuro;
    final factor = 1.0 - (discountPct.clamp(0, 40) / 100.0);
    final v = fareEuro * factor;
    return (v * 10).roundToDouble() / 10;
  }

  static Future<Map<RiderVehicleCategory, CategorySupplySnapshot>>
      loadForPickup({
    required AddressResult pickup,
    AddressResult? destination,

    /// When false: full tariff estimate and no return-discount badge on rows.
    bool returnTripFareEstimatesEnabled = false,
  }) async {
    final supabase = await _loadFromSupabase(
      pickup: pickup,
      destination: destination,
      returnTripFareEstimatesEnabled: returnTripFareEstimatesEnabled,
    );
    return supabase;
  }

  static Future<Map<RiderVehicleCategory, CategorySupplySnapshot>>
      _loadFromSupabase({
    required AddressResult pickup,
    AddressResult? destination,
    required bool returnTripFareEstimatesEnabled,
  }) async {
    final tripKm = destination != null
        ? distanceKm(pickup.lat, pickup.lng, destination.lat, destination.lng)
        : 2.0;

    List<dynamic> rows;
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_nearby_supply',
        params: {
          'p_lat': pickup.lat,
          'p_lng': pickup.lng,
          'p_radius_km': searchRadiusKm,
          'p_max_age_minutes': maxLocationAge.inMinutes,
        },
      );
      rows = raw is List ? raw : const [];
    } catch (_) {
      rows = const [];
    }

    if (rows.isEmpty) {
      return {
        for (final c in RiderVehicleCategory.values)
          c: CategorySupplySnapshot.empty(c),
      };
    }

    final byCategory = <RiderVehicleCategory, List<NearbyDriverOffer>>{
      for (final c in RiderVehicleCategory.values) c: <NearbyDriverOffer>[],
    };

    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final driverId = row['driver_id']?.toString();
      if (driverId == null || driverId.isEmpty) continue;
      final dKm = (row['distance_km'] as num?)?.toDouble();
      if (dKm == null) continue;
      if (dKm > searchRadiusKm) continue;

      final rawCat = row['vehicle_category'] as String?;
      final cat =
          RiderVehicleCategory.tryParse(rawCat) ?? _categoryForDriver(driverId);

      final base = (row['base_fare'] as num?)?.toDouble() ?? _fallbackBase;
      final perKm = (row['per_km_rate'] as num?)?.toDouble() ?? _fallbackPerKm;
      final fullFare =
          _computeFare(tripKm: tripKm, baseFare: base, perKmRate: perKm);
      final rawDiscount =
          ((row['active_return_discount_pct'] as num?)?.toDouble() ?? 0.0)
              .clamp(0, 40)
              .toDouble();
      final discount = returnTripFareEstimatesEnabled ? rawDiscount : 0.0;
      final fare = returnTripFareEstimatesEnabled && rawDiscount > 0
          ? applyReturnTripDiscountToFare(fullFare, rawDiscount)
          : fullFare;

      byCategory[cat]!.add(NearbyDriverOffer(
        driverId: driverId,
        driverName: (row['full_name'] as String?)?.trim().isNotEmpty == true
            ? row['full_name'] as String
            : _fallbackDriverLabel(),
        driverPhoto: row['profile_photo_url'] as String?,
        driverRating: (row['rating'] as num?)?.toDouble() ?? 5.0,
        distanceKmPickup: dKm,
        estimatedFareEuro: fare,
        baseFare: base,
        perKmRate: perKm,
        returnDiscountPct: discount,
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
