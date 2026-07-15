import 'dart:math';

import 'package:heycaby_api/src/supabase_client.dart';

/// Presentation client for the server-owned masked ride communication policy.
///
/// No telephone number is accepted or returned. Flutter can only ask whether
/// communication is allowed and request a ride-scoped bridge.
class MaskedRideCallingService {
  const MaskedRideCallingService();

  Future<RideCommunicationPermissions> permissions({
    required String rideId,
  }) async {
    final raw = await HeyCabySupabase.client.rpc(
      'fn_ride_communication_permissions',
      params: <String, dynamic>{'p_ride_request_id': rideId},
    );
    if (raw is! Map) {
      return const RideCommunicationPermissions.unavailable('invalid_response');
    }
    return RideCommunicationPermissions.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<MaskedCallStartResult> startCall({
    required String rideId,
    String? idempotencyKey,
  }) async {
    try {
      final response = await HeyCabySupabase.client.functions.invoke(
        'ride-masked-call-start',
        body: <String, dynamic>{
          'ride_request_id': rideId,
          'idempotency_key': idempotencyKey ?? _secureUuidV4(),
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        return const MaskedCallStartResult.failed('invalid_response');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['ok'] != true) {
        return MaskedCallStartResult.failed(
          data['error']?.toString() ?? 'calling_unavailable',
        );
      }
      return MaskedCallStartResult.started(
        attemptId: data['attempt_id']?.toString() ?? '',
        status: data['status']?.toString() ?? 'queued',
      );
    } catch (_) {
      return const MaskedCallStartResult.failed(
        'calling_temporarily_unavailable',
      );
    }
  }

  static String _secureUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class RideCommunicationPermissions {
  const RideCommunicationPermissions({
    required this.allowed,
    required this.canCall,
    required this.canMessage,
    required this.maxCallSeconds,
    this.participantRole,
    this.rideStatus,
    this.callAvailableUntil,
    this.messageAvailableUntil,
    this.todayRidesUntil,
    this.reason,
  });

  const RideCommunicationPermissions.unavailable(this.reason)
      : allowed = false,
        canCall = false,
        canMessage = false,
        maxCallSeconds = 300,
        participantRole = null,
        rideStatus = null,
        callAvailableUntil = null,
        messageAvailableUntil = null,
        todayRidesUntil = null;

  final bool allowed;
  final bool canCall;
  final bool canMessage;
  final int maxCallSeconds;
  final String? participantRole;
  final String? rideStatus;
  final DateTime? callAvailableUntil;
  final DateTime? messageAvailableUntil;
  final DateTime? todayRidesUntil;
  final String? reason;

  factory RideCommunicationPermissions.fromJson(Map<String, dynamic> json) =>
      RideCommunicationPermissions(
        allowed: json['allowed'] == true,
        canCall: json['can_call'] == true,
        canMessage: json['can_message'] == true,
        maxCallSeconds: (json['max_call_seconds'] as num?)?.toInt() ?? 300,
        participantRole: json['participant_role']?.toString(),
        rideStatus: json['ride_status']?.toString(),
        callAvailableUntil: _date(json['call_available_until']),
        messageAvailableUntil: _date(json['message_available_until']),
        todayRidesUntil: _date(json['today_rides_until']),
        reason: json['reason']?.toString(),
      );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
}

class MaskedCallStartResult {
  const MaskedCallStartResult.started({
    required this.attemptId,
    required this.status,
  })  : ok = true,
        error = null;

  const MaskedCallStartResult.failed(this.error)
      : ok = false,
        attemptId = null,
        status = null;

  final bool ok;
  final String? attemptId;
  final String? status;
  final String? error;
}
