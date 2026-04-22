import 'package:supabase_flutter/supabase_flutter.dart';

/// How many riders joined via this user's short invite link (see `rider_invite_signups`).
Future<int> fetchMyInvitedFriendsCount(SupabaseClient client) async {
  if (client.auth.currentSession == null) return 0;
  try {
    final raw = await client.rpc('fn_my_invited_friends_count');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
  } catch (_) {}
  return 0;
}

/// Records invite attribution for the signed-in rider identity (invitee).
/// Idempotent: safe to call on every cold start if [code] is the pending deep-link code.
Future<void> tryRecordRiderInviteAttribution(
  SupabaseClient client,
  String? code,
) async {
  if (code == null || code.isEmpty) return;
  final norm = code.trim();
  if (!RegExp(r'^[a-zA-Z0-9]{7}$').hasMatch(norm)) return;
  if (client.auth.currentSession == null) return;
  try {
    await client.rpc(
      'fn_record_rider_invite_attribution',
      params: {'p_invite_code': norm},
    );
  } catch (_) {}
}
