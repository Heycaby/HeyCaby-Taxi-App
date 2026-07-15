import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../services/sound_service.dart';
import '../utils/rider_driver_ping.dart';
import 'rider_ride_snapshot_service.dart';

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
  rating,
  generic,
}

RiderNotificationBehavior behaviorForCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('incoming_ride') || c.contains('ride_offer')) {
    return RiderNotificationBehavior.rideOffer;
  }
  if (c.contains('driver_found') ||
      c.contains('driver_assigned') ||
      c.contains('driver_en_route')) {
    return RiderNotificationBehavior.driverAccepted;
  }
  if (DriverPingType.isPingCategory(c)) {
    if (c.contains('outside')) {
      return RiderNotificationBehavior.driverPingOutside;
    }
    if (c.contains('arrived')) {
      return RiderNotificationBehavior.driverPingArrived;
    }
    if (c.contains('on_my_way') ||
        c.contains('nearby') ||
        c.contains('near_pickup')) {
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
  if (c.contains('rating')) return RiderNotificationBehavior.rating;
  if (c.contains('trip_start') ||
      c.contains('ride_start') ||
      c.contains('in_progress')) {
    return RiderNotificationBehavior.tripStarted;
  }
  if (c.contains('ride_arrived') || c.contains('driver_arrived')) {
    return RiderNotificationBehavior.driverPingArrived;
  }
  if (c.contains('near_pickup')) {
    return RiderNotificationBehavior.driverPingOnMyWay;
  }
  return RiderNotificationBehavior.generic;
}

Future<void> playRiderNotificationFeedback(
    RiderNotificationBehavior behavior) async {
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
    case RiderNotificationBehavior.rating:
      await HapticService.lightTap();
      await sound.playNotification();
    case RiderNotificationBehavior.generic:
      await HapticService.lightTap();
      await sound.playNotification();
  }
}

String riderDeepLinkForBehavior(RiderNotificationBehavior behavior) {
  switch (behavior) {
    case RiderNotificationBehavior.chat:
      return '/chat';
    case RiderNotificationBehavior.payment:
      return '/active';
    case RiderNotificationBehavior.rating:
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
  Future<void> Function()? onOpen,
}) async {
  final behavior = behaviorForCategory(category);
  if (!await _rideNotificationIsCurrent(category, data)) return;
  if (!context.mounted) return;
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

  if (behavior == RiderNotificationBehavior.rating) {
    _showRiderRatingPill(
      context: context,
      title: title,
      body: body,
      onOpen: () {
        if (onOpen != null) {
          unawaited(onOpen());
        } else if (context.mounted) {
          context.go(riderDeepLinkForBehavior(behavior));
        }
      },
    );
    return;
  }

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
          if (onOpen != null) {
            unawaited(onOpen());
          } else if (context.mounted) {
            context.go(riderDeepLinkForBehavior(behavior));
          }
        },
      ),
    ),
  );
}

Future<bool> _rideNotificationIsCurrent(
  String? category,
  Map<String, dynamic>? data,
) async {
  final rideId = data?['ride_request_id']?.toString();
  if (rideId == null || rideId.isEmpty) return true;
  final normalized = (category ?? '').toLowerCase();
  if (normalized.contains('cancel')) return true;
  if (normalized.contains('rating')) return true;
  try {
    final row = await RiderRideSnapshotService.fetch(rideRequestId: rideId);
    final status = row?['status']?.toString().toLowerCase();
    return const {
      'pending',
      'bidding',
      'assigned',
      'accepted',
      'driver_found',
      'driver_en_route',
      'driver_arrived',
      'arrived',
      'in_progress',
    }.contains(status);
  } catch (_) {
    // During a disconnect, suppress unverifiable ride-state overlays. The
    // notifications center can recover them after backend truth is restored.
    return false;
  }
}

void _showRiderRatingPill({
  required BuildContext context,
  required String title,
  required String body,
  required VoidCallback onOpen,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final displayTitle = title.trim().isNotEmpty
      ? title.trim()
      : AppLocalizations.of(context).rateYourDriver;
  final displayBody = body.trim();

  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (overlayContext) => PositionedDirectional(
      bottom: MediaQuery.paddingOf(overlayContext).bottom + 16,
      start: 16,
      end: 16,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label: displayBody.isEmpty
                ? displayTitle
                : '$displayTitle. $displayBody',
            child: InkWell(
              onTap: () {
                remove();
                onOpen();
              },
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101828).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFDB022),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (displayBody.isNotEmpty)
                            Text(
                              displayBody,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD0D5DD),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 3), remove);
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
