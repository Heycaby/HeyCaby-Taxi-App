import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../services/driver_notification_router.dart';
import '../utils/driver_rider_cancelled_flow.dart';

/// Polls backend driver notifications and surfaces new unread items in-app.
/// This is needed for Flutter drivers (no PWA notification UI).
class DriverNotificationsListener extends ConsumerStatefulWidget {
  const DriverNotificationsListener({super.key});

  @override
  ConsumerState<DriverNotificationsListener> createState() =>
      _DriverNotificationsListenerState();
}

class _DriverNotificationsListenerState
    extends ConsumerState<DriverNotificationsListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
  bool _notificationsDisabled = false;
  final Set<String> _handledIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _poll();
    }
  }

  Future<void> _poll() async {
    if (_busy || !mounted || _notificationsDisabled) return;
    _busy = true;
    try {
      final api = ref.read(driverApiProvider);
      final unread = await api.getNotifications(unreadOnly: true, limit: 20);
      if (!mounted || unread.isEmpty) return;

      // API returns newest first; we show older first for natural order.
      final ordered = unread.reversed.toList();
      for (final n in ordered) {
        if (_handledIds.contains(n.id)) continue;
        _handledIds.add(n.id);

        final category = (n.category ?? '').toLowerCase();
        if (category == 'ride_phase') {
          final rideId = n.data?['ride_request_id']?.toString();
          if (rideId != null && rideId.isNotEmpty && mounted) {
            await handleDriverRiderCancelled(
              ref: ref,
              context: context,
              rideId: rideId,
            );
          }
          await api.markNotificationRead(n.id);
          continue;
        }
        if (category == 'incoming_ride') {
          await api.markNotificationRead(n.id);
          continue;
        }

        if (!mounted) return;
        await dispatchDriverNotification(
          context: context,
          category: n.category,
          title: n.title,
          body: n.body,
          data: n.data,
          fromTap: false,
          foreground: true,
        );
        await api.markNotificationRead(n.id);
      }
    } on DioException catch (e) {
      // If this host/session is unauthorized for notifications, stop polling for this app session.
      if (e.response?.statusCode == 401) {
        _notificationsDisabled = true;
      }
    } catch (_) {
      // Silent: notification polling should never break core UX.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
