import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'chat_provider.dart';

/// Unread driver → rider chat messages for an active ride (`messages.is_read`).
final riderRideUnreadMessageCountProvider = NotifierProvider.autoDispose
    .family<RiderRideUnreadMessageCountNotifier, int, String>(
  RiderRideUnreadMessageCountNotifier.new,
);

class RiderRideUnreadMessageCountNotifier
    extends AutoDisposeFamilyNotifier<int, String> {
  @override
  int build(String rideId) {
    final chat = ref.watch(chatProvider).valueOrNull;
    if (chat == null) return 0;
    return chat.messages
        .where((message) =>
            message.rideId == rideId &&
            message.senderType == 'driver' &&
            !message.isRead)
        .length;
  }

  /// Call when the rider opens the full ride chat screen.
  Future<void> markAllRead() async {
    final rideId = arg;
    try {
      await HeyCabySupabase.client
          .from('messages')
          .update({'is_read': true})
          .eq('ride_request_id', rideId)
          .eq('sender_type', 'driver')
          .eq('is_read', false);
      ref.read(chatProvider.notifier).markDriverMessagesReadLocally();
      state = 0;
    } catch (_) {
      // Keep the canonical in-memory count when the backend rejects the write.
    }
  }
}
