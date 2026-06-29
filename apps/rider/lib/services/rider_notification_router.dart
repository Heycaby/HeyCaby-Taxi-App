import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../services/sound_service.dart';
import '../utils/rider_driver_ping.dart';

/// Permanent notification behavior matrix (Program 3C).
///
/// See [apps/driver/docs/NOTIFICATION_MATRIX.md] for the full spec.
enum RiderNotificationBehavior {
  rideOffer,
  driverAccepted,
  driverPingOnMyWay,
  driverPingOutside,
  driverPingArrived,
  driverPingOther,
  chat,
  rideCancelled,
  tripStarted,
  tripCompleted,
  payment,
  generic,
}

RiderNotificationBehavior behaviorForCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('incoming_ride') || c.contains('ride_offer')) {
    return RiderNotificationBehavior.rideOffer;
  }
  if (c.contains('driver_found') || c.contains('driver_assigned')) {
    return RiderNotificationBehavior.driverAccepted;
  }
  if (DriverPingType.isPingCategory(c)) {
    if (c.contains('outside')) return RiderNotificationBehavior.driverPingOutside;
    if (c.contains('arrived')) return RiderNotificationBehavior.driverPingArrived;
    if (c.contains('on_my_way') || c.contains('nearby')) {
      return RiderNotificationBehavior.driverPingOnMyWay;
    }
    return RiderNotificationBehavior.driverPingOther;
  }
  if (c.contains('chat')) return RiderNotificationBehavior.chat;
  if (c.contains('cancel')) return RiderNotificationBehavior.rideCancelled;
  if (c.contains('trip_complete') || c.contains('ride_complete')) {
    return RiderNotificationBehavior.tripCompleted;
  }
  if (c.contains('payment')) return RiderNotificationBehavior.payment;
  if (c.contains('trip_start') || c.contains('in_progress')) {
    return RiderNotificationBehavior.tripStarted;
  }
  return RiderNotificationBehavior.generic;
}

Future<void> playRiderNotificationFeedback(RiderNotificationBehavior behavior) async {
  final sound = SoundService();
  switch (behavior) {
    case RiderNotificationBehavior.rideOffer:
      await HapticService.heavyTap();
      await sound.playNotification();
    case RiderNotificationBehavior.driverAccepted:
      await HapticService.mediumTap();
      await sound.playDriverFound();
    case RiderNotificationBehavior.driverPingOnMyWay:
      await HapticService.pingStandard();
      await sound.playDriverPingOnMyWay();
    case RiderNotificationBehavior.driverPingOutside:
    case RiderNotificationBehavior.driverPingArrived:
      await HapticService.pingUrgent();
      await sound.playDriverPingOutside();
    case RiderNotificationBehavior.driverPingOther:
      await HapticService.pingStandard();
      await sound.playDriverPingOnMyWay();
    case RiderNotificationBehavior.chat:
      await HapticService.lightTap();
      await sound.playNotification();
    case RiderNotificationBehavior.rideCancelled:
      await HapticService.error();
      await sound.playDriverCancelled();
    case RiderNotificationBehavior.tripStarted:
      await HapticService.mediumTap();
      await sound.playDriverFound();
    case RiderNotificationBehavior.tripCompleted:
      await HapticService.lightTap();
      await sound.playTripComplete();
    case RiderNotificationBehavior.payment:
      await HapticService.lightTap();
      await sound.playPaymentSuccess();
    case RiderNotificationBehavior.generic:
      await HapticService.lightTap();
      await sound.playNotification();
  }
}

String riderDeepLinkForBehavior(RiderNotificationBehavior behavior) {
  switch (behavior) {
    case RiderNotificationBehavior.chat:
      return '/support';
    case RiderNotificationBehavior.payment:
      return '/account';
    case RiderNotificationBehavior.rideOffer:
      return '/home';
    default:
      return '/active';
  }
}

/// Routes foreground FCM + polled notifications through one matrix.
Future<void> dispatchRiderNotification({
  required BuildContext context,
  required String? category,
  required String title,
  required String body,
  Map<String, dynamic>? data,
  bool usePingBanner = false,
}) async {
  final behavior = behaviorForCategory(category);
  final pingType = DriverPingType.tryParse(
    data?['ping_kind']?.toString() ?? category,
  );

  if (usePingBanner && DriverPingType.isPingCategory(category)) {
    await showRiderDriverPingAlert(
      context: context,
      title: title,
      body: body,
      category: category,
      pingKind: data?['ping_kind']?.toString(),
      data: data,
      pingType: pingType,
    );
    unawaited(_markPingOpened(data, pingType));
    return;
  }

  unawaited(playRiderNotificationFeedback(behavior));

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l10n = AppLocalizations.of(context);

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        title.isNotEmpty ? '$title\n$body' : body,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.openAction,
        onPressed: () {
          if (context.mounted) {
            context.go(riderDeepLinkForBehavior(behavior));
          }
        },
      ),
    ),
  );
}

Future<void> _markPingOpened(
  Map<String, dynamic>? data,
  DriverPingType? pingType,
) async {
  if (pingType == null) return;
  final rideId = data?['ride_request_id']?.toString();
  if (rideId == null || rideId.isEmpty) return;
  try {
    await HeyCabySupabase.client.rpc('fn_rider_ping_mark_opened', params: {
      'p_ride_id': rideId,
      'p_ping_kind': pingType.apiKind,
    });
  } catch (_) {
    // Best-effort until RPC is deployed in all envs.
  }
}

