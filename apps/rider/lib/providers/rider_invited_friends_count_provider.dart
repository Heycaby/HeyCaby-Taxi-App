import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Successful invitees attributed via `fn_record_rider_invite_attribution` (Supabase).
final riderInvitedFriendsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  if (!identity.hasSession) return 0;
  return fetchMyInvitedFriendsCount(HeyCabySupabase.client);
});
