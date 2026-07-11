import 'package:heycaby_api/heycaby_api.dart';

class RiderMyRidesService {
  const RiderMyRidesService();

  static const _pageSize = 100;

  Future<List<Map<String, dynamic>>> fetchAll({
    required String scope,
  }) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_my_rides',
        params: {
          'p_scope': scope,
          'p_limit': _pageSize,
          'p_offset': offset,
        },
      );
      if (response is! Map || response['ok'] != true) {
        final error = response is Map ? response['error'] : null;
        throw StateError(
          'Unable to load rider rides: ${error ?? 'invalid_response'}',
        );
      }

      final rawItems = response['items'];
      final page = rawItems is List
          ? rawItems
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : <Map<String, dynamic>>[];
      all.addAll(page);

      if (response['has_more'] != true || page.isEmpty) break;
      offset += page.length;
    }

    return all;
  }
}
