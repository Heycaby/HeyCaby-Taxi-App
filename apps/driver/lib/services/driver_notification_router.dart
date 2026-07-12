import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
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
  if (c.contains('verification')) {
    return DriverNotificationBehavior.verification;
  }
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

  if (behavior == DriverNotificationBehavior.chat) {
    _showRideSignalPill(
      context: context,
      body: body.isNotEmpty ? body : title,
      onOpen: () => context.push(
        driverDeepLinkForBehavior(behavior, data: data),
      ),
    );
    return;
  }

  if (behavior == DriverNotificationBehavior.rating) {
    _showTransientNotificationPill(
      context: context,
      title: title.isNotEmpty ? title : '⭐ You received a new rating',
      body: body.isNotEmpty ? body : '',
      onOpen: () => context.push(
        driverDeepLinkForBehavior(behavior, data: data),
      ),
      autoDismissSeconds: 3,
    );
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
        label: DriverStrings.notificationOpenAction,
        onPressed: () {
          if (context.mounted) {
            context.push(driverDeepLinkForBehavior(behavior, data: data));
          }
        },
      ),
    ),
  );
}

void _showRideSignalPill({
  required BuildContext context,
  required String body,
  required VoidCallback onOpen,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || body.trim().isEmpty) return;
  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (overlayContext) => PositionedDirectional(
      top: MediaQuery.paddingOf(overlayContext).top + 10,
      start: 16,
      end: 16,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label: 'Ride signals. $body',
            child: InkWell(
              onTap: () {
                remove();
                onOpen();
              },
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 10, 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF101828).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF12B76A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ride signals',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD0D5DD),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF98A2B3),
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
  Timer(const Duration(seconds: 4), remove);
}

void _showTransientNotificationPill({
  required BuildContext context,
  required String title,
  required String body,
  required VoidCallback onOpen,
  int autoDismissSeconds = 3,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final displayBody = body.trim().isNotEmpty ? body.trim() : null;
  if (title.trim().isEmpty && displayBody == null) return;

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
            label: displayBody == null ? title : '$title. $displayBody',
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (displayBody != null)
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
  Timer(Duration(seconds: autoDismissSeconds), remove);
}
