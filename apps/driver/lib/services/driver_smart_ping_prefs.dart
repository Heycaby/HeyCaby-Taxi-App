import 'package:shared_preferences/shared_preferences.dart';

import '../services/driver_ping_cooldown.dart';

/// Persists smart-ping dismiss + infers "already sent" from cooldown keys.
class DriverSmartPingPrefs {
  const DriverSmartPingPrefs();

  static String _dismissKey(String rideId, String kind) =>
      'driver_smart_ping_dismiss_${rideId}_$kind';

  Future<bool> isDismissed(String rideId, String kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissKey(rideId, kind)) ?? false;
  }

  Future<void> dismiss(String rideId, String kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey(rideId, kind), true);
  }

  bool wasPingSentRecently(String rideId, String pingKind) {
    return !DriverPingCooldown.canSend(rideId, pingKind);
  }
}
