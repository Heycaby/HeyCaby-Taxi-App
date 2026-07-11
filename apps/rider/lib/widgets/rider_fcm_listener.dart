import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/ride_matching_variant.dart';
import '../providers/ride_request_provider.dart';
import '../services/rider_notification_router.dart';
import '../services/rider_ride_lifecycle_engine.dart';

/// Rider FCM wiring for foreground, notification taps, and cold-start opens.
class RiderFcmListener extends ConsumerStatefulWidget {
  const RiderFcmListener({super.key});

  @override
  ConsumerState<RiderFcmListener> createState() => _RiderFcmListenerState();
}

class _RiderFcmListenerState extends ConsumerState<RiderFcmListener> {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _initialMessageHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wire());
  }

  Future<void> _wire() async {
    if (!mounted) return;
    if (HeyCabySupabase.client.auth.currentUser == null) return;

    _foregroundSub ??=
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_openFromMessage(message));
    });

    if (_initialMessageHandled) return;
    _initialMessageHandled = true;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _openFromMessage(initial);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('RiderFcmListener getInitialMessage: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    final category = data['category']?.toString();
    final title =
        message.notification?.title ?? data['title']?.toString() ?? '';
    final body = message.notification?.body ?? data['body']?.toString() ?? '';

    unawaited(_refreshLiveActivityFromPush(data, category));

    unawaited(dispatchRiderNotification(
      context: context,
      category: category,
      title: title,
      body: body,
      data: Map<String, dynamic>.from(data),
      usePingBanner: DriverPingType.isPingCategory(category),
      onOpen: () => _openFromMessage(message),
    ));
  }

  Future<void> _openFromMessage(RemoteMessage message) async {
    if (!mounted) return;
    final data = Map<String, dynamic>.from(message.data);
    final category = data['category']?.toString();
    await _refreshLiveActivityFromPush(data, category);
    final rideId = _rideIdFromData(data);
    final behavior = behaviorForCategory(category);

    if (rideId != null && rideId.isNotEmpty) {
      final attached = await ref
          .read(rideRequestProvider.notifier)
          .attachRideRequestForMatchingFlow(rideId);
      if (!mounted) return;
      if (attached) {
        final ride = ref.read(rideRequestProvider);
        final status = (ride.status ?? '').toLowerCase();
        if (_isActiveRideStatus(status)) {
          context.go(
            behavior == RiderNotificationBehavior.chat ? '/chat' : '/active',
          );
          return;
        }
        if (status == 'pending' || status == 'bidding') {
          context.go(
            rideMatchingVariantForBookingModeString(ride.bookingMode).routePath,
          );
          return;
        }
      }
    }

    if (!mounted) return;
    context.go(riderDeepLinkForBehavior(behavior));
  }

  Future<void> _refreshLiveActivityFromPush(
    Map<String, dynamic> data,
    String? category,
  ) async {
    if (!isRideLifecyclePushCategory(category)) return;
    var rideId = _rideIdFromData(data);
    rideId ??= ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null || rideId.isEmpty) return;
    await riderRideLifecycleEngineRefreshFromServer(
      ref,
      rideRequestId: rideId,
      source: 'fcm',
    );
  }

  String? _rideIdFromData(Map<String, dynamic> data) =>
      rideRequestIdFromPushData(data);

  bool _isActiveRideStatus(String status) {
    return status == 'assigned' ||
        status == 'accepted' ||
        status == 'driver_found' ||
        status == 'driver_en_route' ||
        status == 'driver_arrived' ||
        status == 'arrived' ||
        status == 'in_progress';
  }

  @override
  void dispose() {
    unawaited(_foregroundSub?.cancel());
    unawaited(_openedSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
