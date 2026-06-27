import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'sound_service.dart';

/// Permanent driver notification matrix (Program 3C).
///
/// See [../docs/NOTIFICATION_MATRIX.md].
enum DriverNotificationBehavior {
  incomingRide,
  rideCancelled,
  chat,
  rating,
  verification,
  shiftHandover,
  taxiSessionRevoked,
  generic,
}

DriverNotificationBehavior driverBehaviorForCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('incoming_ride') || c.contains('ride_offer')) {
    return DriverNotificationBehavior.incomingRide;
  }
  if (c.contains('ride_phase') || c.contains('cancel')) {
    return DriverNotificationBehavior.rideCancelled;
  }
  if (c.contains('chat')) return DriverNotificationBehavior.chat;
  if (c.contains('rating')) return DriverNotificationBehavior.rating;
  if (c.contains('verification')) return DriverNotificationBehavior.verification;
  if (c.contains('shift_handover')) {
    return DriverNotificationBehavior.shiftHandover;
  }
  if (c.contains('taxi_session_revoked')) {
    return DriverNotificationBehavior.taxiSessionRevoked;
  }
  return DriverNotificationBehavior.generic;
}

Future<void> playDriverNotificationFeedback(
  DriverNotificationBehavior behavior,
) async {
  final sound = SoundService();
  switch (behavior) {
    case DriverNotificationBehavior.incomingRide:
      await HapticService.heavyTap();
      await sound.playRideRequest();
    case DriverNotificationBehavior.rideCancelled:
      await HapticService.error();
      await sound.playRiderCancelled();
    case DriverNotificationBehavior.chat:
      await HapticService.lightTap();
      await sound.playNotification();
    case DriverNotificationBehavior.rating:
      await HapticService.lightTap();
      await sound.playNotification();
    case DriverNotificationBehavior.verification:
      await HapticService.mediumTap();
      await sound.playNotification();
    case DriverNotificationBehavior.shiftHandover:
      await HapticService.heavyTap();
      await sound.playNotification();
    case DriverNotificationBehavior.taxiSessionRevoked:
      await HapticService.heavyTap();
      await sound.playNotification();
    case DriverNotificationBehavior.generic:
      await HapticService.lightTap();
      await sound.playNotification();
  }
}

String driverDeepLinkForBehavior(
  DriverNotificationBehavior behavior, {
  Map<String, dynamic>? data,
}) {
  final rideId = data?['ride_request_id']?.toString();
  switch (behavior) {
    case DriverNotificationBehavior.chat:
      if (rideId != null && rideId.isNotEmpty) return '/driver/chat/$rideId';
      return '/driver/support';
    case DriverNotificationBehavior.rating:
      return '/driver/score';
    case DriverNotificationBehavior.verification:
      return '/driver/documents';
    case DriverNotificationBehavior.incomingRide:
      if (rideId != null && rideId.isNotEmpty) {
        return '/driver/ride/new/$rideId';
      }
      return '/driver';
    default:
      return '/driver';
  }
}

/// Foreground FCM + polled notifications — one matrix for sound/haptic/snackbar.
Future<void> dispatchDriverNotification({
  required BuildContext context,
  required String? category,
  required String title,
  required String body,
  Map<String, dynamic>? data,
  required bool fromTap,
  bool foreground = false,
}) async {
  final behavior = driverBehaviorForCategory(category);

  if (foreground && !fromTap) {
    if (behavior == DriverNotificationBehavior.incomingRide) {
      // Incoming ride uses looping ringtone via dedicated handler.
    } else {
      unawaited(playDriverNotificationFeedback(behavior));
    }
  }

  if (fromTap) {
    if (!context.mounted) return;
    context.push(driverDeepLinkForBehavior(behavior, data: data));
    return;
  }

  if (!foreground || behavior == DriverNotificationBehavior.incomingRide) {
    return;
  }

  if (behavior == DriverNotificationBehavior.shiftHandover ||
      behavior == DriverNotificationBehavior.taxiSessionRevoked) {
    return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final display = title.isNotEmpty ? '$title\n$body' : body;
  if (display.trim().isEmpty) return;

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        display,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () {
          if (context.mounted) {
            context.push(driverDeepLinkForBehavior(behavior, data: data));
          }
        },
      ),
    ),
  );
}
