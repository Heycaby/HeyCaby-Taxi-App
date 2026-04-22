import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/rider_vehicle_category.dart';
import '../services/nearby_supply_service.dart';
import 'booking_provider.dart';
import 'nearby_category_supply_provider.dart';

/// Typical trip price (€) from live driver rates near pickup, with RPC fallback.
final marketplaceReferenceFareEuroProvider =
    FutureProvider.autoDispose<double?>((ref) async {
  final booking = ref.watch(bookingProvider);
  final pickup = booking.pickup;
  final destination = booking.destination;
  if (pickup == null || destination == null) return null;

  final snap = await ref.watch(nearbyCategorySupplyProvider.future);

  final cat = RiderVehicleCategory.tryParse(booking.vehicleCategory ?? '') ??
      RiderVehicleCategory.standard;
  final chosen = snap[cat];
  if (chosen != null &&
      chosen.driverCount > 0 &&
      chosen.fromPriceEuro != null) {
    return chosen.fromPriceEuro;
  }

  double? best;
  for (final s in snap.values) {
    if (s.driverCount > 0 && s.fromPriceEuro != null) {
      final p = s.fromPriceEuro!;
      if (best == null || p < best) best = p;
    }
  }
  if (best != null) return best;

  return _medianFareFromRpc(pickup, destination);
});

Future<double?> _medianFareFromRpc(
  AddressResult pickup,
  AddressResult destination,
) async {
  final tripKm = NearbySupplyService.distanceKm(
    pickup.lat,
    pickup.lng,
    destination.lat,
    destination.lng,
  );
  if (tripKm <= 0) return null;

  final durationMin = (tripKm / 0.5).ceil().clamp(5, 240);
  try {
    final rows = await HeyCabySupabase.client.rpc(
      'calculate_trip_fares',
      params: {
        'p_trip_distance_km': tripKm,
        'p_trip_duration_min': durationMin,
        'p_rider_longitude': pickup.lng,
        'p_rider_latitude': pickup.lat,
      },
    );
    if (rows is! List<dynamic>) return null;
    final fares = <double>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final f = row['calculated_fare'];
      if (f is num) fares.add(f.toDouble());
    }
    if (fares.isEmpty) return null;
    fares.sort();
    return fares[fares.length ~/ 2];
  } catch (_) {
    return null;
  }
}

int marketplaceMatchPercent(double referenceEuro, int bidEuro) {
  if (referenceEuro <= 0) return 0;
  return math.min(100, (bidEuro / referenceEuro * 100).round());
}

int marketplaceSavingsPercent(double referenceEuro, int bidEuro) {
  if (referenceEuro <= 0 || bidEuro >= referenceEuro) return 0;
  return (((referenceEuro - bidEuro) / referenceEuro) * 100).round();
}

double marketplaceSavingsEuro(double referenceEuro, int bidEuro) {
  if (referenceEuro <= 0) return 0;
  return math.max(0, referenceEuro - bidEuro);
}

String formatMarketplaceEuro(double value) {
  if ((value - value.round()).abs() < 0.05) {
    return '€${value.round()}';
  }
  return '€${value.toStringAsFixed(1)}';
}
