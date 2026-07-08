import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/rider_vehicle_category.dart';
import '../utils/rider_effective_locale_bridge.dart';
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

/// Zone-based supply counts from SDA supply snapshot RPC.
class RiderSupplySnapshot {
  const RiderSupplySnapshot({
    required this.zone1Count,
    required this.zone2Count,
    required this.zone3Count,
    required this.totalCount,
    this.closestKm,
    this.fastestEtaMin,
    required this.rpcSucceeded,
  });

  final int zone1Count;
  final int zone2Count;
  final int zone3Count;
  final int totalCount;
  final double? closestKm;
  final double? fastestEtaMin;
  final bool rpcSucceeded;

  static const RiderSupplySnapshot empty = RiderSupplySnapshot(
    zone1Count: 0,
    zone2Count: 0,
    zone3Count: 0,
    totalCount: 0,
    rpcSucceeded: false,
  );
}

/// Online favourite drivers near the rider's pickup probe point.
class RiderFavoriteSupplySnapshot {
  const RiderFavoriteSupplySnapshot({
    required this.onlineCount,
    this.closestKm,
    required this.rpcSucceeded,
  });

  final int onlineCount;
  final double? closestKm;
  final bool rpcSucceeded;

  static const RiderFavoriteSupplySnapshot empty = RiderFavoriteSupplySnapshot(
    onlineCount: 0,
    rpcSucceeded: false,
  );
}

/// Result of a live supply probe at pickup — distinguishes empty vs failed RPC.
class NearbySupplyProbe {
  const NearbySupplyProbe({
    required this.driverCount,
    required this.rpcSucceeded,
  });

  final int driverCount;
  final bool rpcSucceeded;

  bool get hasKnownEmptySupply => rpcSucceeded && driverCount == 0;
}

/// Loads live driver supply near pickup, joins real driver pricing + profile.
class NearbySupplyService {
  static String _fallbackDriverLabel() {
    final code = RiderEffectiveLocaleBridge.languageCode;
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

  static List<dynamic> _parseRpcRows(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const [];
  }

  /// Quick count for home map / no-supply banners.
  static Future<NearbySupplyProbe> probeDriverCount({
    required AddressResult pickup,
  }) async {
    final snapshot = await loadSupplySnapshot(pickup: pickup);
    if (snapshot.rpcSucceeded) {
      return NearbySupplyProbe(
        driverCount: snapshot.totalCount,
        rpcSucceeded: true,
      );
    }
    return _probeDriverCountLegacy(pickup: pickup);
  }

  /// SDA zone counts for the home supply chip.
  static Future<RiderSupplySnapshot> loadSupplySnapshot({
    required AddressResult pickup,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_supply_snapshot',
        params: {
          'p_lat': pickup.lat,
          'p_lng': pickup.lng,
        },
      );
      if (raw is! Map) return RiderSupplySnapshot.empty;
      final row = Map<String, dynamic>.from(raw);
      return RiderSupplySnapshot(
        zone1Count: (row['zone1_count'] as num?)?.toInt() ?? 0,
        zone2Count: (row['zone2_count'] as num?)?.toInt() ?? 0,
        zone3Count: (row['zone3_count'] as num?)?.toInt() ?? 0,
        totalCount: (row['total_count'] as num?)?.toInt() ?? 0,
        closestKm: (row['closest_km'] as num?)?.toDouble(),
        fastestEtaMin: (row['fastest_eta_min'] as num?)?.toDouble(),
        rpcSucceeded: true,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('NearbySupplyService.loadSupplySnapshot failed: $e\n$st');
      }
      return RiderSupplySnapshot.empty;
    }
  }

  /// Favourite drivers who are online with a fresh location near [pickup].
  static Future<RiderFavoriteSupplySnapshot> loadFavoriteSupplySnapshot({
    required AddressResult pickup,
    required Set<String> favoriteDriverIds,
  }) async {
    if (favoriteDriverIds.isEmpty) {
      return RiderFavoriteSupplySnapshot.empty;
    }
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
      final rows = _parseRpcRows(raw);
      var count = 0;
      double? closestKm;
      for (final row in rows) {
        if (row is! Map) continue;
        final driverId = row['driver_id']?.toString();
        if (driverId == null || !favoriteDriverIds.contains(driverId)) {
          continue;
        }
        final dKm = (row['distance_km'] as num?)?.toDouble();
        if (dKm == null || dKm > searchRadiusKm) continue;
        count++;
        if (closestKm == null || dKm < closestKm) {
          closestKm = dKm;
        }
      }
      return RiderFavoriteSupplySnapshot(
        onlineCount: count,
        closestKm: closestKm,
        rpcSucceeded: true,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'NearbySupplyService.loadFavoriteSupplySnapshot failed: $e\n$st',
        );
      }
      return RiderFavoriteSupplySnapshot.empty;
    }
  }

  /// Legacy row-based supply probe (falls back when snapshot RPC unavailable).
  static Future<NearbySupplyProbe> _probeDriverCountLegacy({
    required AddressResult pickup,
  }) async {
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
      final rows = _parseRpcRows(raw);
      var count = 0;
      for (final row in rows) {
        if (row is! Map) continue;
        final driverId = row['driver_id']?.toString();
        if (driverId == null || driverId.isEmpty) continue;
        count++;
      }
      return NearbySupplyProbe(driverCount: count, rpcSucceeded: true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('NearbySupplyService._probeDriverCountLegacy failed: $e\n$st');
      }
      return const NearbySupplyProbe(driverCount: 0, rpcSucceeded: false);
    }
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
      rows = _parseRpcRows(raw);
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
