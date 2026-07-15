import 'package:heycaby_api/heycaby_api.dart';

/// The only Rider read door for business state on one ride.
abstract final class RiderRideSnapshotService {
  static Future<Map<String, dynamic>?> fetch({
    required String rideRequestId,
    String? riderToken,
  }) async {
    var token = riderToken?.trim();
    if (token == null || token.isEmpty) {
      final stored = await SecureStorage.getRiderIdentity();
      token = stored['rider_token']?.trim();
    }

    final raw = await HeyCabySupabase.client.rpc(
      'fn_rider_ride_snapshot',
      params: {
        'p_ride_request_id': rideRequestId,
        if (token != null && token.isNotEmpty) 'p_rider_token': token,
      },
    );
    if (raw is! Map) return null;
    final result = Map<String, dynamic>.from(raw);
    return result['ok'] == true ? result : null;
  }
}
