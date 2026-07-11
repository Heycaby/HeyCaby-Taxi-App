import 'package:heycaby_api/heycaby_api.dart';

import '../models/taxi_terug_queue_status.dart';

/// Phase 4 — rider queue visibility for Taxi Terug bookings.
class TaxiTerugQueueService {
  Future<TaxiTerugQueueStatus?> fetch(
    String rideRequestId, {
    String? riderToken,
  }) async {
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_taxi_terug_queue_status',
        params: {
          'p_ride_request_id': rideRequestId,
          if (riderToken != null && riderToken.trim().isNotEmpty)
            'p_rider_token': riderToken.trim(),
        },
      );
      return TaxiTerugQueueStatus.parseRpc(res);
    } catch (_) {
      return null;
    }
  }
}
