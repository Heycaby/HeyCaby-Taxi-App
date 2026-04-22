import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Persists shift sessions to `driver_shift_sessions` (migration 039) when available.
/// Fails silently if the table or columns are missing so the UI still works from `drivers` shift fields.
class DriverShiftSessionService {
  final _client = HeyCabySupabase.client;

  /// Call after the driver successfully goes online (available).
  Future<void> ensureShiftSessionStarted(String driverId) async {
    try {
      final existing = await _client
          .from('drivers')
          .select('current_shift_id')
          .eq('id', driverId)
          .maybeSingle();
      if (existing != null && existing['current_shift_id'] != null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      final inserted = await _client
          .from('driver_shift_sessions')
          .insert({
            'driver_id': driverId,
            'shift_started_at': now,
            'is_active': true,
            'break_reminder_interval_minutes': 120,
            'breaks': [],
          })
          .select('id')
          .maybeSingle();

      final sessionId = inserted?['id'];
      if (sessionId != null) {
        await _client.from('drivers').update({
          'current_shift_id': sessionId,
          'shift_started_at': now,
        }).eq('id', driverId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ensureShiftSessionStarted: $e');
    }
  }

  /// Call when the driver ends shift (offline). Backend may also do this via API.
  Future<void> endShiftSession(String driverId) async {
    try {
      final row = await _client
          .from('drivers')
          .select('current_shift_id, shift_total_online_minutes, shift_break_minutes, shift_rides_today, shift_earnings_today')
          .eq('id', driverId)
          .maybeSingle();
      final sid = row?['current_shift_id'];
      if (sid != null) {
        await _client.from('driver_shift_sessions').update({
          'shift_ended_at': DateTime.now().toUtc().toIso8601String(),
          'is_active': false,
        }).eq('id', sid);
      }
      await _client.from('drivers').update({
        'current_shift_id': null,
      }).eq('id', driverId);
    } catch (e) {
      if (kDebugMode) debugPrint('endShiftSession: $e');
    }
  }
}
