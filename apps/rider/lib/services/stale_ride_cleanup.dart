import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Best-effort: mark an old pending/bidding ride cancelled so it does not trap the rider UI.
Future<void> cancelExpiredRiderOpenRide({
  required String rideId,
  required String riderToken,
  String cancellationReason = 'search_window_expired',
}) async {
  try {
    await HeyCabySupabase.client
        .from('ride_requests')
        .update({
          'status': 'cancelled',
          'cancelled_by': 'rider',
          'cancellation_reason': cancellationReason,
        })
        .eq('id', rideId)
        .eq('rider_token', riderToken);
  } catch (e) {
    if (kDebugMode) debugPrint('cancelExpiredRiderOpenRide: $e');
  }
}
