import 'package:heycaby_api/heycaby_api.dart';

import '../models/driver_ping_timeline.dart';

/// Fetches ping audit timeline for active ride support UI.
class DriverPingTimelineService {
  const DriverPingTimelineService();

  Future<List<DriverPingTimelineItem>> fetch(String rideRequestId) async {
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_ride_ping_timeline',
        params: {'p_ride_id': rideRequestId},
      );
      if (res is! Map) return const [];
      if (res['ok'] != true) return const [];
      final items = res['items'];
      if (items is! List) return const [];
      final rows = items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return groupPingTimelineRows(rows);
    } catch (_) {
      return const [];
    }
  }
}
