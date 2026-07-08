import 'package:heycaby_api/src/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-first in-app notifications (Phase D — Backend Consolidation).
class AppNotificationsService {
  const AppNotificationsService();

  Future<List<Map<String, dynamic>>?> listOrNull({
    required String userType,
    bool unreadOnly = false,
    int limit = 30,
    String? riderIdentityId,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_app_notifications_list',
        params: {
          'p_user_type': userType,
          'p_unread_only': unreadOnly,
          'p_limit': limit,
          if (riderIdentityId != null && riderIdentityId.isNotEmpty)
            'p_rider_identity_id': riderIdentityId,
        },
      );
      if (raw is! Map || raw['ok'] != true) return null;
      final list = raw['notifications'];
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> list({
    required String userType,
    bool unreadOnly = false,
    int limit = 30,
    String? riderIdentityId,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_app_notifications_list',
        params: {
          'p_user_type': userType,
          'p_unread_only': unreadOnly,
          'p_limit': limit,
          if (riderIdentityId != null && riderIdentityId.isNotEmpty)
            'p_rider_identity_id': riderIdentityId,
        },
      );
      if (raw is! Map || raw['ok'] != true) return const [];
      final list = raw['notifications'];
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> markRead(String notificationId) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_app_notification_mark_read',
        params: {'p_notification_id': notificationId},
      );
      return raw is Map && raw['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllRead({
    required String userType,
    String? riderIdentityId,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_app_notifications_mark_all_read',
        params: {
          'p_user_type': userType,
          if (riderIdentityId != null && riderIdentityId.isNotEmpty)
            'p_rider_identity_id': riderIdentityId,
        },
      );
      return raw is Map && raw['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearRead({
    required String userType,
    String? riderIdentityId,
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_app_notifications_clear_read',
        params: {
          'p_user_type': userType,
          if (riderIdentityId != null && riderIdentityId.isNotEmpty)
            'p_rider_identity_id': riderIdentityId,
        },
      );
      return raw is Map && raw['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Realtime channel; callback fires on notifications table changes.
  /// Pass [filterUserId] to filter at the database level and avoid receiving
  /// every user's notification events.
  RealtimeChannel subscribeToTableChanges({
    required String channelName,
    required void Function(PostgresChangePayload payload) onChange,
    String? filterUserId,
    String? filterUserType,
  }) {
    var channel = HeyCabySupabase.client.channel(channelName);
    if (filterUserId != null && filterUserId.isNotEmpty) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: filterUserId,
        ),
        callback: onChange,
      );
    } else {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: onChange,
      );
    }
    return channel.subscribe();
  }
}
