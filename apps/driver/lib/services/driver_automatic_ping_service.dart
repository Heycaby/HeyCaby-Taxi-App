import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// System-initiated pings (accept / GPS / arrived). Silent — no snackbars.
/// Server dedupes once per `(ride_id, kind)` when `automatic: true`.
class DriverAutomaticPingService {
  const DriverAutomaticPingService();

  static String _localKey(String rideId, String kind) =>
      'driver_auto_ping_${rideId}_$kind';

  Future<bool> sendIfNeeded({
    required String rideRequestId,
    required DriverPingType type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localKey(rideRequestId, type.apiKind);
    if (prefs.getBool(key) == true) return false;

    try {
      final res = await HeyCabySupabase.client.functions.invoke(
        'driver-agent',
        body: {
          'event': 'driver_ping',
          'ride_request_id': rideRequestId,
          'kind': type.apiKind,
          'automatic': true,
        },
      );
      final data = res.data;
      if (data is Map && data['skipped'] == true) {
        await prefs.setBool(key, true);
        return false;
      }
      await prefs.setBool(key, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
