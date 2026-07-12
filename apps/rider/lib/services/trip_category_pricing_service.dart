import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/trip_category_estimate.dart';

/// Fetches per-category trip estimates from Supabase RPC (no hardcoded rates).
class TripCategoryPricingService {
  TripCategoryPricingService._();

  static Future<List<TripCategoryEstimate>> fetchEstimates({
    required double pickupLng,
    required double pickupLat,
    required double destLng,
    required double destLat,
    double? distanceKm,
    double? durationMin,
  }) async {
    dynamic raw = await HeyCabySupabase.client.rpc(
      'fn_estimate_trip_category_prices',
      params: <String, dynamic>{
        'p_pickup_lng': pickupLng,
        'p_pickup_lat': pickupLat,
        'p_dest_lng': destLng,
        'p_dest_lat': destLat,
        'p_distance_km': distanceKm,
        'p_duration_min': durationMin,
      },
    );

    if (raw == null) return [];

    if (raw is String) {
      try {
        raw = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        return [];
      }
    }

    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else {
      if (kDebugMode) {
        debugPrint('fn_estimate_trip_category_prices: unexpected $raw');
      }
      return [];
    }

    final out = <TripCategoryEstimate>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final e = TripCategoryEstimate.tryParseMap(item);
        if (e != null) out.add(e);
      }
    }
    return out;
  }
}
