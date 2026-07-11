import 'package:heycaby_api/heycaby_api.dart';

import '../utils/rider_journey_progress.dart';

/// Rider-side ping timeline (shared audit log with driver app).
class RiderRidePingService {
  const RiderRidePingService();

  Future<bool> driverOnMyWay(String rideRequestId, {String? riderToken}) async {
    final rows = await fetchRows(rideRequestId, riderToken: riderToken);
    return RiderJourneyProgress.timelineIncludesOnMyWay(rows);
  }

  Future<List<Map<String, dynamic>>> fetchRows(
    String rideRequestId, {
    String? riderToken,
  }) async {
    try {
      final params = <String, dynamic>{'p_ride_id': rideRequestId};
      final token = riderToken?.trim();
      if (token != null && token.isNotEmpty) {
        params['p_rider_token'] = token;
      }
      final res = await HeyCabySupabase.client.rpc(
        'fn_ride_ping_timeline',
        params: params,
      );
      if (res is! Map || res['ok'] != true) return const [];
      final items = res['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
