import 'dart:math';

import 'package:heycaby_api/src/supabase_client.dart';

class RideChatSendException implements Exception {
  const RideChatSendException(this.code);

  final String code;

  @override
  String toString() => 'RideChatSendException($code)';
}

/// Canonical Rider <-> Driver ride-chat command client.
class HeyCabyRideChatMessages {
  HeyCabyRideChatMessages._();

  static final Random _secureRandom = Random.secure();

  /// A process-independent 128-bit retry key. The same key must be reused when
  /// retrying an uncertain send so the backend returns the original message.
  static String newIdempotencyKey() {
    final bytes = List<int>.generate(
      16,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    );
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<Map<String, dynamic>> send({
    required String rideId,
    required String idempotencyKey,
    required String content,
    String messageType = 'text',
  }) async {
    final raw = await HeyCabySupabase.client.rpc(
      'fn_send_ride_message',
      params: {
        'p_ride_id': rideId,
        'p_idempotency_key': idempotencyKey,
        'p_content': content,
        'p_message_type': messageType,
      },
    );
    if (raw is! Map || raw['ok'] != true || raw['message'] is! Map) {
      throw RideChatSendException(
        raw is Map ? raw['code']?.toString() ?? 'send_failed' : 'send_failed',
      );
    }
    return Map<String, dynamic>.from(raw['message'] as Map);
  }
}
