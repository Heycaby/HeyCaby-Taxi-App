import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';

import '../services/rider_notification_router.dart';

/// Compact foreground ride signal. It stays above content and never covers
/// the bottom ride CTA; the active ride screen remains the permanent center.
Future<void> showRiderDriverPingAlert({
  required BuildContext context,
  required String title,
  required String body,
  String? category,
  String? pingKind,
  Map<String, dynamic>? data,
  DriverPingType? pingType,
}) async {
  final type = pingType ?? DriverPingType.tryParse(pingKind ?? category);
  final behavior = behaviorForCategory(
    type?.notificationCategory ?? category,
  );
  unawaited(playRiderNotificationFeedback(behavior));

  final vehicleLabel = data?['vehicle_label']?.toString().trim() ?? '';
  final plate = data?['vehicle_plate']?.toString().trim() ?? '';

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final l10n = AppLocalizations.of(context);
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            remove();
            if (context.mounted) context.go('/active');
          },
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsetsDirectional.fromSTEB(13, 11, 9, 11),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF12B76A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(type), color: Colors.white, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.activeRidePingDriver,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (title.isNotEmpty || body.isNotEmpty)
                        Text(
                          body.isNotEmpty ? body : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD0D5DD),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (vehicleLabel.isNotEmpty || plate.isNotEmpty) ...[
                        Text(
                          [vehicleLabel, plate]
                              .where((v) => v.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 4), remove);
}

IconData _iconFor(DriverPingType? type) {
  switch (type) {
    case DriverPingType.outside:
      return Icons.door_front_door_outlined;
    case DriverPingType.arrived:
      return Icons.place_rounded;
    case DriverPingType.runningLate:
    case DriverPingType.trafficDelay:
      return Icons.schedule_rounded;
    case DriverPingType.cantFindRider:
      return Icons.person_search_outlined;
    case DriverPingType.thanks:
      return Icons.thumb_up_alt_outlined;
    case DriverPingType.onMyWay:
    case null:
      return Icons.directions_car_filled;
  }
}
