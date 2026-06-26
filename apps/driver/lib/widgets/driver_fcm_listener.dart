import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../services/driver_fcm_handler.dart';
import '../services/driver_fcm_payload.dart';

/// Wires FCM foreground, background tap, and cold-start open (Program 3C).
class DriverFcmListener extends ConsumerStatefulWidget {
  const DriverFcmListener({super.key});

  @override
  ConsumerState<DriverFcmListener> createState() => _DriverFcmListenerState();
}

class _DriverFcmListenerState extends ConsumerState<DriverFcmListener> {
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
        FirebaseMessaging.onMessage.listen((message) => _dispatch(
              message,
              fromTap: false,
              foreground: true,
            ));

    _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) =>
        _dispatch(message, fromTap: true, foreground: false));

    if (_initialMessageHandled) return;
    _initialMessageHandled = true;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _dispatch(initial, fromTap: true, foreground: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DriverFcmListener getInitialMessage: $e');
    }
  }

  Future<void> _dispatch(
    RemoteMessage message, {
    required bool fromTap,
    required bool foreground,
  }) async {
    if (!mounted) return;
    final payload = DriverFcmPayload.fromRemoteMessage(message);
    if (payload.effectiveCategory == null &&
        payload.rideRequestId == null) {
      return;
    }
    await DriverFcmHandler.dispatch(
      payload: payload,
      ref: ref,
      context: context,
      fromTap: fromTap,
      foreground: foreground,
    );
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
