/// Client-side 30s cooldown mirror (server enforces via [ride_audit_log] too).
class DriverPingCooldown {
  DriverPingCooldown._();

  static const cooldown = Duration(seconds: 30);
  static final Map<String, DateTime> _lastSent = {};

  static String _key(String rideId, String pingKind) => '$rideId:$pingKind';

  static bool canSend(String rideId, String pingKind) {
    final last = _lastSent[_key(rideId, pingKind)];
    if (last == null) return true;
    return DateTime.now().difference(last) >= cooldown;
  }

  static Duration? remaining(String rideId, String pingKind) {
    final last = _lastSent[_key(rideId, pingKind)];
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= cooldown) return null;
    return cooldown - elapsed;
  }

  static void markSent(String rideId, String pingKind) {
    _lastSent[_key(rideId, pingKind)] = DateTime.now();
  }
}
