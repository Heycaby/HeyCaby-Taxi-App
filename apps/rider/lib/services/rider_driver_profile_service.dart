import 'package:heycaby_api/heycaby_api.dart';

/// Loads assigned driver profile for an active ride (SECURITY DEFINER RPC).
class RiderDriverProfileService {
  RiderDriverProfileService._();

  static Future<Map<String, dynamic>?> fetchForRide({
    required String rideRequestId,
    String? riderToken,
  }) async {
    final params = <String, dynamic>{
      'p_ride_request_id': rideRequestId,
    };
    final token = riderToken?.trim();
    if (token != null && token.isNotEmpty) {
      params['p_rider_token'] = token;
    }
    try {
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_driver_profile_for_ride',
        params: params,
      );
      if (response is! Map) return null;
      final map = Map<String, dynamic>.from(response);
      return map.isEmpty ? null : map;
    } catch (_) {
      return null;
    }
  }
}
