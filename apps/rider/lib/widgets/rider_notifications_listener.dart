import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Polls backend rider notifications and surfaces unread admin/system messages.
class RiderNotificationsListener extends ConsumerStatefulWidget {
  const RiderNotificationsListener({super.key});

  @override
  ConsumerState<RiderNotificationsListener> createState() =>
      _RiderNotificationsListenerState();
}

class _RiderNotificationsListenerState
    extends ConsumerState<RiderNotificationsListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n.title.isNotEmpty ? '${n.title}\n${n.body}' : n.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 6),
        action: (n.category == 'account_action' || n.category == 'verification')
            ? SnackBarAction(
                label: 'Open',
                onPressed: () {
                  if (!mounted) return;
                  context.go('/account');
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
