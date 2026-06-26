import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../services/rider_notification_router.dart';

/// Foreground FCM for rider — routes all categories through [dispatchRiderNotification].
class RiderFcmListener extends ConsumerStatefulWidget {
  const RiderFcmListener({super.key});

  @override
  ConsumerState<RiderFcmListener> createState() => _RiderFcmListenerState();
}

class _RiderFcmListenerState extends ConsumerState<RiderFcmListener> {
  StreamSubscription<RemoteMessage>? _foregroundSub;

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
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    final category = data['category']?.toString();
    final title = message.notification?.title ??
        data['title']?.toString() ??
        '';
    final body = message.notification?.body ??
        data['body']?.toString() ??
        '';

    unawaited(dispatchRiderNotification(
      context: context,
      category: category,
      title: title,
      body: body,
      data: Map<String, dynamic>.from(data),
      usePingBanner: DriverPingType.isPingCategory(category),
    ));
  }

  @override
  void dispose() {
    unawaited(_foregroundSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
