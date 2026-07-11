import 'supabase_client.dart';

/// Keeps `rider_sessions.session_token` aligned with the device `rider_token`.
class RiderSessionService {
  const RiderSessionService();

  Future<bool> bindToken(String? token) async {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_bind_session_token',
        params: {'p_token': trimmed},
      );
      return res is Map && res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Canonical token stored on `ride_requests` for [rideRequestId].
  Future<String?> fetchRideRiderToken(
    String rideRequestId, {
    String? hintToken,
  }) async {
    final id = rideRequestId.trim();
    if (id.isEmpty) return null;
    final hint = hintToken?.trim();
    try {
      final res = await HeyCabySupabase.client.rpc(
        'fn_rider_fetch_ride_token',
        params: {
          'p_ride_id': id,
          if (hint != null && hint.isNotEmpty) 'p_hint_token': hint,
        },
      );
      if (res is Map && res['ok'] == true) {
        final token = res['rider_token']?.toString().trim();
        if (token != null && token.isNotEmpty) return token;
      }
    } catch (_) {
      // Fall back to direct read on older backends.
    }
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select('rider_token')
          .eq('id', id)
          .maybeSingle();
      final token = row?['rider_token']?.toString().trim();
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }
}
