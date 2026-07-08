import 'package:heycaby_api/heycaby_api.dart';

import 'rider_plate_verification_storage.dart';

/// Syncs rider plate attestations to Supabase (`fn_rider_attest_plate`).
class RiderPlateVerificationService {
  RiderPlateVerificationService._();

  static Future<bool> isVerifiedOnServer(String rideRequestId) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_plate_attestation_for_ride',
        params: {'p_ride_request_id': rideRequestId},
      );
      if (raw is! Map) return false;
      final map = Map<String, dynamic>.from(raw);
      return map['ok'] == true && map['verified'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> attestOnServer({
    required String rideRequestId,
    required String expectedPlate,
    String outcome = 'confirmed',
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_attest_plate',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_expected_plate': expectedPlate,
          'p_outcome': outcome,
        },
      );
      if (raw is! Map) return false;
      return Map<String, dynamic>.from(raw)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Push any offline attestations saved on device.
  static Future<void> syncPendingQueue() async {
    final pending = await RiderPlateVerificationStorage.loadAll();
    for (final record in pending) {
      final ok = await attestOnServer(
        rideRequestId: record.rideRequestId,
        expectedPlate: record.expectedPlate,
      );
      if (ok) {
        await RiderPlateVerificationStorage.removeForRide(record.rideRequestId);
      }
    }
  }
}
