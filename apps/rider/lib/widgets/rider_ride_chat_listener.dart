import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../providers/ride_request_provider.dart';
import '../providers/rider_ride_unread_messages_provider.dart';
import '../utils/ride_chat_allowed.dart';

/// Keeps ride chat realtime + unread counts alive while a ride is active,
/// even when the rider stays on `/active` instead of opening `/chat`.
class RiderRideChatListener extends ConsumerStatefulWidget {
  const RiderRideChatListener({super.key});

  @override
  ConsumerState<RiderRideChatListener> createState() =>
      _RiderRideChatListenerState();
}

class _RiderRideChatListenerState extends ConsumerState<RiderRideChatListener> {
  String? _subscribedRideId;

  void _syncSubscription(String? rideId, String? status) {
    final allowed = rideId != null && isRideChatAllowed(status);
    if (!allowed) {
      _subscribedRideId = null;
      return;
    }
    if (_subscribedRideId == rideId) return;
    _subscribedRideId = rideId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _subscribedRideId != rideId) return;
      ref.read(chatProvider.notifier).loadMessages(rideId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(rideRequestProvider);
    final rideId = ride.rideRequestId;
    final status = ride.status;

    _syncSubscription(rideId, status);

    if (rideId != null && isRideChatAllowed(status)) {
      ref.watch(chatProvider);
      ref.watch(riderRideUnreadMessageCountProvider(rideId));
    }

    return const SizedBox.shrink();
  }
}
