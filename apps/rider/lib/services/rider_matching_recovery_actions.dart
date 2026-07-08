import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/ride_matching_variant.dart';
import '../providers/active_search_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/rider_notify_search_notifications.dart';

const _terminalRideStatuses = {
  'cancelled',
  'canceled',
  'rejected',
  'declined',
  'missed',
  'expired',
  'completed',
  'finished',
};

/// Shared recovery actions after a failed or expired driver search.
class RiderMatchingRecoveryActions {
  RiderMatchingRecoveryActions._();

  static Future<void> tryAgain(WidgetRef ref, BuildContext context) async {
    ref.read(rideRequestProvider.notifier).reset();
    if (context.mounted) context.go('/summary');
  }

  static Future<void> notifyMe(WidgetRef ref, BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final granted =
        await RiderNotifySearchNotifications.ensureNotifyPermission();
    if (!granted) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.accountNotificationsNeededBody),
          action: SnackBarAction(
            label: l10n.openNotificationSettings,
            onPressed: () => openAppSettings(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;

    final booking = ref.read(bookingProvider);
    if (booking.pickup == null || booking.destination == null) {
      if (context.mounted) context.go('/home');
      return;
    }

    final rideNotifier = ref.read(rideRequestProvider.notifier);
    var rideId = ref.read(rideRequestProvider).rideRequestId;
    final status = ref.read(rideRequestProvider).status;
    final needsNewRide = rideId == null ||
        (status != null && _terminalRideStatuses.contains(status));
    if (needsNewRide) {
      final ok = await rideNotifier.createRide(booking);
      if (!ok || !context.mounted) return;
      rideId = ref.read(rideRequestProvider).rideRequestId;
    }

    final mode = bookingModeStorageString(booking.effectiveRideMode);
    await ref.read(activeSearchProvider.notifier).start(
          rideRequestId: rideId,
          bookingMode: mode,
          pickupSummary: booking.pickup?.displayName,
          destinationSummary: booking.destination?.displayName,
        );
    ref.read(rideRequestProvider.notifier).reset();
    if (context.mounted) context.go('/home');
  }

  static void schedule(WidgetRef ref, BuildContext context) {
    ref.read(rideRequestProvider.notifier).reset();
    ref.read(bookingProvider.notifier).setScheduled();
    if (context.mounted) context.go('/search');
  }

  static void marketplace(WidgetRef ref, BuildContext context) {
    ref.read(rideRequestProvider.notifier).reset();
    ref.read(bookingProvider.notifier).setMarketplace();
    if (context.mounted) {
      context.go(RideMatchingVariant.marketplace.routePath);
    }
  }
}
