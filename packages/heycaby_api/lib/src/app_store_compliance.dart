import 'dart:convert';

import 'package:dio/dio.dart';
import 'supabase_client.dart';

/// Thrown when account deletion (Auth API) fails.
class HeyCabyAccountDeletionException implements Exception {
  HeyCabyAccountDeletionException(this.message);
  final String message;

  @override
  String toString() => 'HeyCabyAccountDeletionException: $message';
}

/// App Store Guideline 5.1.1(v) — delete the signed-in Supabase Auth user.
///
/// Requires the project to allow user self-deletion (Supabase Dashboard → Authentication).
/// Call [deleteDriverOwnedData] first so application rows are removed.
class HeyCabyAccountDeletion {
  HeyCabyAccountDeletion._();

  /// Removes the `drivers` row for `auth.uid()` before deleting the Auth user.
  static Future<Map<String, dynamic>> deleteDriverOwnedData() async {
    final res = await HeyCabySupabase.client.rpc('fn_delete_driver_owned_data');
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'success': false, 'error': 'unexpected_response'};
  }

  /// DELETE /auth/v1/user with the current access token, then local sign-out.
  static Future<void> deleteCurrentSupabaseAuthUser() async {
    final session = HeyCabySupabase.client.auth.currentSession;
    if (session == null) {
      throw HeyCabyAccountDeletionException('not_signed_in');
    }

    final dio = Dio();
    final url = '${HeyCabySupabase.supabaseUrl}/auth/v1/user';
    try {
      final res = await dio.delete<dynamic>(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': HeyCabySupabase.supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code != 200 && code != 204) {
        throw HeyCabyAccountDeletionException(
          'auth_delete_status_$code:${res.data}',
        );
      }
    } on DioException catch (e) {
      throw HeyCabyAccountDeletionException(e.message ?? 'network_error');
    }

    await HeyCabySupabase.client.auth.signOut();
  }
}

/// Blocked participant in a ride chat thread (from [fn_ride_chat_list_blocks]).
class RideChatBlockEntry {
  const RideChatBlockEntry({
    required this.blockedId,
    required this.blockedType,
  });

  final String blockedId;
  final String blockedType;
}

/// Ride chat blocking (App Store user-generated content expectations).
/// Deletes rider rows using the same token stored as `rider_token` in secure storage.
class HeyCabyRiderAccountDeletion {
  HeyCabyRiderAccountDeletion._();

  /// [riderIdentityId] should be the stored rider identity UUID when available — the DB uses
  /// it to delete rows when `user_id` was never backfilled on `rider_identities`.
  static Future<Map<String, dynamic>> deleteBySessionToken(
    String sessionToken, {
    String? riderIdentityId,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_session_token': sessionToken.trim(),
        if (riderIdentityId != null && riderIdentityId.trim().isNotEmpty)
          'p_rider_identity_id': riderIdentityId.trim(),
      };
      final res = await HeyCabySupabase.client.rpc(
        'fn_delete_rider_account',
        params: params,
      );
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      // PostgREST / network — surface message so callers can log or show support hints.
      return {'success': false, 'error': e.toString()};
    }
  }
}

class HeyCabyRideChatBlocks {
  HeyCabyRideChatBlocks._();

  static List<RideChatBlockEntry> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return _parseList(decoded);
      } catch (_) {
        return [];
      }
    }
    if (raw is! List) return [];
    final out = <RideChatBlockEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final id = m['blocked_id'] as String? ?? '';
      final type = m['blocked_type'] as String? ?? '';
      if (id.isEmpty || type.isEmpty) continue;
      out.add(RideChatBlockEntry(blockedId: id, blockedType: type));
    }
    return out;
  }

  static Future<List<RideChatBlockEntry>> listForBlocker({
    required String rideId,
    required String blockerId,
    required String blockerType,
  }) async {
    final raw = await HeyCabySupabase.client.rpc(
      'fn_ride_chat_list_blocks',
      params: {
        'p_ride_id': rideId,
        'p_blocker_id': blockerId,
        'p_blocker_type': blockerType,
      },
    );
    return _parseList(raw);
  }

  static Future<bool> blockParticipant({
    required String rideId,
    required String blockerId,
    required String blockerType,
    required String blockedId,
    required String blockedType,
  }) async {
    final res = await HeyCabySupabase.client.rpc(
      'fn_ride_chat_block_participant',
      params: {
        'p_ride_id': rideId,
        'p_blocker_id': blockerId,
        'p_blocker_type': blockerType,
        'p_blocked_id': blockedId,
        'p_blocked_type': blockedType,
      },
    );
    if (res is Map && res['success'] == true) return true;
    if (res is Map<String, dynamic> && res['success'] == true) return true;
    return false;
  }
}

/// Ride chat reports (App Store UGC — report objectionable content / users).
class HeyCabyRideChatReports {
  HeyCabyRideChatReports._();

  static Future<bool> reportParticipant({
    required String rideId,
    required String reporterId,
    required String reporterType,
    required String reportedId,
    required String reportedType,
    String? reason,
  }) async {
    final res = await HeyCabySupabase.client.rpc(
      'fn_ride_chat_report_participant',
      params: {
        'p_ride_id': rideId,
        'p_reporter_id': reporterId,
        'p_reporter_type': reporterType,
        'p_reported_id': reportedId,
        'p_reported_type': reportedType,
        'p_reason': (reason == null || reason.trim().isEmpty)
            ? null
            : reason.trim(),
      },
    );
    if (res is Map && res['success'] == true) return true;
    if (res is Map<String, dynamic> && res['success'] == true) return true;
    return false;
  }
}
