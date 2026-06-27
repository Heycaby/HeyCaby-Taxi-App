import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/rider_community_growth_models.dart';
import 'rider_invited_friends_count_provider.dart';

/// Personal growth impact for the signed-in rider (invite attribution, no cash rewards).
final riderInviteImpactProvider =
    FutureProvider.autoDispose<RiderInviteImpact>((ref) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  if (!identity.hasSession) return RiderInviteImpact.empty;

  final invited = await ref.watch(riderInvitedFriendsCountProvider.future);
  // Successful signups via invite link; ride totals can wire to backend later.
  return RiderInviteImpact(
    peopleInvited: invited,
    joined: invited,
    completedRides: 0,
  );
});
