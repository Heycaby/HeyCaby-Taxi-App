import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_search_provider.dart';
import '../router.dart';
import 'rider_notify_live_activity.dart';
import 'rider_notify_search_notifications.dart';

/// Keeps the ongoing “searching for driver” notification in sync with
/// [activeSearchProvider] and routes taps to `/home`.
class NotifySearchNotificationScope extends ConsumerStatefulWidget {
  final Widget child;

  const NotifySearchNotificationScope({super.key, required this.child});

  @override
  ConsumerState<NotifySearchNotificationScope> createState() =>
      _NotifySearchNotificationScopeState();
}

class _NotifySearchNotificationScopeState
    extends ConsumerState<NotifySearchNotificationScope> {
  @override
  void initState() {
    super.initState();
    RiderNotifySearchNotifications.bindTapHandler(_openHome);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        RiderNotifySearchNotifications
            .handleColdStartIfLaunchedFromNotification(),
      );
    });
  }

  void _openHome() {
    if (!mounted) return;
    ref.read(appRouterProvider).go('/home');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ActiveNotifySearch?>>(
      activeSearchProvider,
      (prev, next) {
        next.when(
          data: (s) {
            if (s == null) {
              unawaited(RiderNotifySearchNotifications.dismiss());
              unawaited(RiderNotifyLiveActivity.end());
            } else {
              unawaited(
                RiderNotifySearchNotifications.showOrUpdate(
                  pickupSummary: s.pickupSummary ?? '',
                  destinationSummary: s.destinationSummary ?? '',
                  startedAt: s.startedAt,
                ),
              );
              final rideRequestId = s.rideRequestId;
              if (rideRequestId != null && rideRequestId.isNotEmpty) {
                unawaited(RiderNotifyLiveActivity.syncNotifySearch(
                  rideRequestId: rideRequestId,
                  pickupSummary: s.pickupSummary ?? '',
                  destinationSummary: s.destinationSummary ?? '',
                  startedAt: s.startedAt,
                ));
              }
            }
          },
          loading: () {},
          error: (_, __) {},
        );
      },
    );
    return widget.child;
  }
}
