import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/taxi_terug_hot_destination.dart';

/// Hot Taxi Terug destinations — live driver counts per NL city.
class TaxiTerugHotDestinationsService {
  TaxiTerugHotDestinationsService();

  Future<List<TaxiTerugHotDestination>> fetchHotDestinations({
    AddressResult? pickup,
  }) async {
    List<TaxiTerugHotDestination> live = const [];
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_taxi_terug_hot_destinations',
        params: {
          if (pickup != null) 'p_pickup_lat': pickup.lat,
          if (pickup != null) 'p_pickup_lng': pickup.lng,
        },
      );
      final map = _mapFromRpc(res);
      if (map['enabled'] == true) {
        final raw = map['destinations'];
        if (raw is List) {
          live = [
            for (final item in raw)
              if (item is Map)
                TaxiTerugHotDestination.fromJson(
                  Map<String, dynamic>.from(item),
                ),
          ].whereType<TaxiTerugHotDestination>().toList();
        }
      }
    } catch (_) {
      live = const [];
    }

    if (live.isEmpty) {
      return kTaxiTerugNlHotCities;
    }

    return _mergeWithDefaults(live);
  }

  List<TaxiTerugHotDestination> _mergeWithDefaults(
    List<TaxiTerugHotDestination> live,
  ) {
    final byCity = {for (final d in live) d.city.toLowerCase(): d};
    final merged = kTaxiTerugNlHotCities.map((fallback) {
      final hit = byCity[fallback.city.toLowerCase()];
      return hit ?? fallback;
    }).toList();

    final known = merged.map((d) => d.city.toLowerCase()).toSet();
    for (final extra in live) {
      if (!known.contains(extra.city.toLowerCase())) {
        merged.add(extra);
      }
    }

    merged.sort((a, b) {
      final countCmp = b.driverCount.compareTo(a.driverCount);
      if (countCmp != 0) return countCmp;
      return a.city.compareTo(b.city);
    });
    return merged;
  }

  Map<String, dynamic> _mapFromRpc(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return const {};
  }
}
