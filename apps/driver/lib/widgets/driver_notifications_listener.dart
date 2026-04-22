import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';

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
        _showNotificationSnack(n);
        await api.markNotificationRead(n.id);
      }
    } catch (_) {
      // Silent: notification polling should never break core UX.
    } finally {
      _busy = false;
    }
  }

  void _showNotificationSnack(DriverNotificationItem n) {
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
        action: n.category == 'verification'
            ? SnackBarAction(
                label: 'Open',
                onPressed: () {
                  if (!mounted) return;
                  context.push('/driver/documents');
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
