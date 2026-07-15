import 'package:heycaby_api/src/supabase_client.dart';

/// Presentation-layer client for backend-owned ride verification commands.
///
/// It never calculates eligibility, distance thresholds, payment state, or
/// refunds. Every result is a projection of the canonical Supabase contract.
class RideVerificationService {
  const RideVerificationService();

  Future<RideVerificationSnapshot> snapshot({
    required String rideId,
    String? riderToken,
  }) async {
    final raw = await HeyCabySupabase.client.rpc(
      'fn_ride_verification_snapshot',
      params: <String, dynamic>{
        'p_ride_id': rideId,
        if (riderToken != null) 'p_rider_token': riderToken,
      },
    );
    return RideVerificationSnapshot.fromRaw(raw);
  }

  Future<Map<String, dynamic>> requestDriverArrival({
    required String rideId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double speedKmh,
    required DateTime recordedAt,
  }) =>
      _rpc('request_driver_arrival', <String, dynamic>{
        'p_ride_id': rideId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_m': accuracyMeters,
        'p_speed_kmh': speedKmh,
        'p_recorded_at': recordedAt.toUtc().toIso8601String(),
      });

  Future<Map<String, dynamic>> verifyBoardingPin({
    required String rideId,
    required String pin,
  }) =>
      _rpc('verify_boarding_pin', <String, dynamic>{
        'p_ride_id': rideId,
        'p_pin': pin.trim(),
      });

  Future<Map<String, dynamic>> startVerifiedRide({required String rideId}) =>
      _rpc('start_verified_ride', <String, dynamic>{'p_ride_id': rideId});

  Future<Map<String, dynamic>> completeVerifiedRide({
    required String rideId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime recordedAt,
  }) =>
      _rpc('complete_verified_ride', <String, dynamic>{
        'p_ride_id': rideId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_m': accuracyMeters,
        'p_recorded_at': recordedAt.toUtc().toIso8601String(),
      });

  Future<Map<String, dynamic>> requestDriverNoShow({required String rideId}) =>
      _rpc('request_driver_no_show', <String, dynamic>{'p_ride_id': rideId});

  Future<Map<String, dynamic>> requestRiderCancellation({
    required String rideId,
    String? riderToken,
    String? reason,
  }) =>
      _rpc('request_rider_cancellation', <String, dynamic>{
        'p_ride_id': rideId,
        if (riderToken != null) 'p_rider_token': riderToken,
        if (reason != null) 'p_reason': reason,
      });

  Future<Map<String, dynamic>> openCase({
    required String rideId,
    required String caseType,
    required String reason,
    String? riderToken,
  }) =>
      _rpc('open_ride_dispute', <String, dynamic>{
        'p_ride_id': rideId,
        'p_case_type': caseType,
        'p_reason': reason,
        if (riderToken != null) 'p_rider_token': riderToken,
      });

  Future<Map<String, dynamic>> recordContact({
    required String rideId,
    required String channel,
    String? outcome,
  }) =>
      _rpc('record_ride_contact_attempt', <String, dynamic>{
        'p_ride_id': rideId,
        'p_channel': channel,
        if (outcome != null) 'p_outcome': outcome,
      });

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final raw = await HeyCabySupabase.client.rpc(name, params: params);
    if (raw is! Map) {
      throw const RideVerificationException('invalid_response');
    }
    final result = Map<String, dynamic>.from(raw);
    if (result['ok'] != true) {
      throw RideVerificationException(
        result['error']?.toString() ?? 'verification_failed',
        details: result,
      );
    }
    return result;
  }
}

class RideVerificationSnapshot {
  const RideVerificationSnapshot({
    required this.ok,
    required this.isProtected,
    required this.arrivalVerified,
    required this.boardingVerified,
    required this.completionVerified,
    required this.riskStatus,
    this.boardingPin,
    this.boardingPinExpiresAt,
    this.waitingTimerStartedAt,
    this.paymentEligibleAt,
  });

  final bool ok;
  final bool isProtected;
  final bool arrivalVerified;
  final bool boardingVerified;
  final bool completionVerified;
  final String riskStatus;
  final String? boardingPin;
  final DateTime? boardingPinExpiresAt;
  final DateTime? waitingTimerStartedAt;
  final DateTime? paymentEligibleAt;

  factory RideVerificationSnapshot.fromRaw(Object? raw) {
    if (raw is! Map || raw['ok'] != true) {
      throw RideVerificationException(
        raw is Map
            ? raw['error']?.toString() ?? 'snapshot_failed'
            : 'invalid_response',
      );
    }
    DateTime? date(Object? value) =>
        value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
    return RideVerificationSnapshot(
      ok: true,
      isProtected: raw['protected'] == true,
      arrivalVerified: raw['arrival_verified'] == true,
      boardingVerified: raw['boarding_verified'] == true,
      completionVerified: raw['completion_verified'] == true,
      riskStatus: raw['risk_status']?.toString() ?? 'clear',
      boardingPin: raw['boarding_pin']?.toString(),
      boardingPinExpiresAt: date(raw['boarding_pin_expires_at']),
      waitingTimerStartedAt: date(raw['waiting_timer_started_at']),
      paymentEligibleAt: date(raw['payment_eligible_at']),
    );
  }
}

class RideVerificationException implements Exception {
  const RideVerificationException(this.code, {this.details = const {}});

  final String code;
  final Map<String, dynamic> details;

  @override
  String toString() => 'RideVerificationException($code)';
}
