import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/taxi_terug_candidate.dart';

/// Taxi Terug supply — candidate browse (Phase 2) via `fn_rider_taxi_terug_candidates`.
class TaxiTerugSupplyService {
  TaxiTerugSupplyService();

  Future<TaxiTerugCandidatesSnapshot> fetchCandidates({
    required AddressResult pickup,
    required AddressResult destination,
    int limit = 10,
    int? maxWaitMinutes,
  }) async {
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_taxi_terug_candidates',
        params: {
          'p_pickup_lat': pickup.lat,
          'p_pickup_lng': pickup.lng,
          'p_destination_lat': destination.lat,
          'p_destination_lng': destination.lng,
          'p_limit': limit,
          if (maxWaitMinutes != null) 'p_max_wait_minutes': maxWaitMinutes,
        },
      );
      final map = _mapFromRpc(res);
      final rawList = map['candidates'];
      final candidates = <TaxiTerugCandidate>[];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            final parsed = TaxiTerugCandidate.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (parsed != null) candidates.add(parsed);
          }
        }
      }
      return TaxiTerugCandidatesSnapshot(
        enabled: map['enabled'] == true,
        candidates: candidates,
        tripDistanceKm: (map['trip_distance_km'] as num?)?.toDouble(),
        reason: map['reason'] as String?,
        rpcSucceeded: true,
      );
    } catch (_) {
      return TaxiTerugCandidatesSnapshot.empty;
    }
  }

  Map<String, dynamic> _mapFromRpc(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return const {};
  }
}
