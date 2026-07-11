import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

const _sessionService = RiderSessionService();

/// Resolves the canonical `rider_token` for [rideId] (DB row wins over device cache).
Future<String?> resolveRiderTokenForRide({
  required String rideId,
  String? riderToken,
  bool bindSession = true,
}) async {
  final dbToken = await _sessionService.fetchRideRiderToken(rideId);
  final resolved = (dbToken ?? riderToken)?.trim();
  if (resolved == null || resolved.isEmpty) return null;
  if (bindSession) {
    await _sessionService.bindToken(resolved);
  }
  return resolved;
}

/// Atomically cancel matching ride, revoke invites, notify drivers.
/// Returns true when the server row is cancelled (or already was).
Future<bool> cancelExpiredRiderOpenRide({
  required String rideId,
  String? riderToken,
  String cancellationReason = 'search_window_expired',
}) async {
  try {
    final token = await resolveRiderTokenForRide(
      rideId: rideId,
      riderToken: riderToken,
    );

    final res = await HeyCabySupabase.client.rpc(
      'fn_rider_cancel_open_ride',
      params: {
        'p_ride_request_id': rideId,
        if (token != null && token.isNotEmpty) 'p_rider_token': token,
        'p_reason': cancellationReason,
      },
    );
    if (res is Map && res['ok'] == true) return true;

    if (kDebugMode) {
      debugPrint(
        'cancelExpiredRiderOpenRide RPC failed: ${res is Map ? res['error'] : res}',
      );
    }

    // Fallback until migration is everywhere — only when we know the row token.
    if (token == null || token.isEmpty) return false;
    final updated = await HeyCabySupabase.client
        .from('ride_requests')
        .update({
          'status': 'cancelled',
          'cancelled_by': 'rider',
          'cancellation_reason': cancellationReason,
        })
        .eq('id', rideId)
        .eq('rider_token', token)
        .inFilter('status', ['pending', 'bidding', 'no_driver'])
        .select('id');
    return updated.isNotEmpty;
  } catch (e) {
    if (kDebugMode) debugPrint('cancelExpiredRiderOpenRide: $e');
    return false;
  }
}
