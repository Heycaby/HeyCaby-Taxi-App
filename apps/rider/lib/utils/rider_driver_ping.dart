import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';

import '../services/rider_notification_router.dart';

/// Rich in-app ping alert (vehicle + plate, green urgent styling).
Future<void> showRiderDriverPingAlert({
  required BuildContext context,
  required String title,
  required String body,
  String? category,
  String? pingKind,
  Map<String, dynamic>? data,
  DriverPingType? pingType,
}) async {
  final type = pingType ??
      DriverPingType.tryParse(pingKind ?? category);
  final behavior = behaviorForCategory(
    type?.notificationCategory ?? category,
  );
  unawaited(playRiderNotificationFeedback(behavior));

  final vehicleLabel = data?['vehicle_label']?.toString().trim() ?? '';
  final plate = data?['vehicle_plate']?.toString().trim() ?? '';

  final urgent = type == DriverPingType.outside ||
      type == DriverPingType.cantFindRider ||
      type == DriverPingType.arrived;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l10n = AppLocalizations.of(context);

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      duration: const Duration(seconds: 10),
      showCloseIcon: true,
      backgroundColor: urgent ? const Color(0xFF1B5E20) : null,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconFor(type),
            color: urgent ? Colors.white : null,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: urgent ? Colors.white : null,
                    ),
                  ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: urgent ? Colors.white70 : null),
                  ),
                if (vehicleLabel.isNotEmpty || plate.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (vehicleLabel.isNotEmpty)
                    Text(
                      vehicleLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: urgent ? Colors.white : null,
                      ),
                    ),
                  if (plate.isNotEmpty)
                    Text(
                      plate,
                      style: TextStyle(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: urgent ? Colors.white : null,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: l10n.openAction,
        textColor: urgent ? Colors.white : null,
        onPressed: () {
          if (context.mounted) context.go('/active');
        },
      ),
    ),
  );
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
