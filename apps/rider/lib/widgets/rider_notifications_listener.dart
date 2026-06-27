import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/rider_notification_router.dart';

/// Supabase-first in-app notifications with Realtime refetch + light backup poll.
class RiderNotificationsListener extends ConsumerStatefulWidget {
  const RiderNotificationsListener({super.key});

  @override
  ConsumerState<RiderNotificationsListener> createState() =>
      _RiderNotificationsListenerState();
}

class _RiderNotificationsListenerState
    extends ConsumerState<RiderNotificationsListener>
    with WidgetsBindingObserver {
  static const _notifications = AppNotificationsService();

  Timer? _backupPollTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _realtimeChannel;
  bool _busy = false;
  final Set<String> _handledIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeRealtime();
    _poll();
    _backupPollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backupPollTimer?.cancel();
    _debounceTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _poll();
    }
  }

  void _subscribeRealtime() {
    final uid = HeyCabySupabase.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _notifications.subscribeToTableChanges(
      channelName: 'rider-notifications-$uid',
      onChange: (_) => _schedulePoll(),
    );
  }

  void _schedulePoll() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _poll);
  }

  Future<void> _poll() async {
    if (_busy || !mounted) return;
    final identity = ref.read(riderIdentityProvider).valueOrNull;
    final riderIdentityId = identity?.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) return;

    _busy = true;
    try {
      final api = ref.read(riderApiProvider);
      final unread = await api.getNotifications(
        riderIdentityId: riderIdentityId,
        unreadOnly: true,
        limit: 20,
      );
      if (!mounted || unread.isEmpty) return;

      final ordered = unread.reversed.toList();
      for (final n in ordered) {
        if (_handledIds.contains(n.id)) continue;
        _handledIds.add(n.id);
        _showNotificationSnack(n);
        await api.markNotificationRead(
          riderIdentityId: riderIdentityId,
          notificationId: n.id,
        );
      }
    } catch (_) {
      // Silent by design.
    } finally {
      _busy = false;
    }
  }

  void _showNotificationSnack(RiderNotificationItem n) {
    if (DriverPingType.isPingCategory(n.category)) {
      unawaited(dispatchRiderNotification(
        context: context,
        category: n.category,
        title: n.title,
        body: n.body,
        data: n.data,
        usePingBanner: true,
      ));
      return;
    }

    unawaited(dispatchRiderNotification(
      context: context,
      category: n.category,
      title: n.title,
      body: n.body,
      data: n.data,
    ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
