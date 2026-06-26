import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and restores pickup wait duration (Program 3B / L2).
///
/// Local prefs survive app kill; [ride_audit_log] backs up when prefs are missing.
class DriverPickupWaitService {
  const DriverPickupWaitService();

  static String prefKey(String rideId) => 'pickup_wait_started_$rideId';

  Future<void> recordStarted(String rideId, {DateTime? at}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefKey(rideId),
      (at ?? DateTime.now().toUtc()).toIso8601String(),
    );
  }

  Future<void> clear(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey(rideId));
  }

  Future<DateTime?> resolveStartedAt(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefKey(rideId));
    final fromPrefs = stored != null ? DateTime.tryParse(stored) : null;
    if (fromPrefs != null) return fromPrefs;

    final fromAudit = await _fetchArrivedAtFromAuditLog(rideId);
    if (fromAudit != null) {
      await recordStarted(rideId, at: fromAudit);
    }
    return fromAudit;
  }

  int elapsedSeconds(DateTime startedAt, {DateTime? now}) {
    final end = (now ?? DateTime.now()).toUtc();
    final start = startedAt.toUtc();
    final seconds = end.difference(start).inSeconds;
    if (seconds < 0) return 0;
    return seconds;
  }

  Future<DateTime?> _fetchArrivedAtFromAuditLog(String rideId) async {
    try {
      final rows = await HeyCabySupabase.client
          .from('ride_audit_log')
          .select('occurred_at, metadata')
          .eq('ride_id', rideId)
          .eq('event', 'ride.status_changed')
          .order('occurred_at', ascending: false)
          .limit(8);

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final metadata = map['metadata'];
        if (metadata is Map &&
            metadata['to_status']?.toString() == 'driver_arrived') {
          final at = map['occurred_at']?.toString();
          if (at != null) {
            final parsed = DateTime.tryParse(at);
            if (parsed != null) return parsed;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DriverPickupWaitService audit fetch: $e');
    }
    return null;
  }
}

/// Parses audit row metadata for pickup-arrival timestamp (unit-tested).
DateTime? driverPickupWaitFromAuditRow(Map<String, dynamic> row) {
  final metadata = row['metadata'];
  if (metadata is! Map || metadata['to_status']?.toString() != 'driver_arrived') {
    return null;
  }
  final at = row['occurred_at']?.toString();
  if (at == null) return null;
  return DateTime.tryParse(at);
}
