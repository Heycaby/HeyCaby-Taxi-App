/// Context-aware communication + smart-ping distance thresholds.
const double kCommunicationNearPickupRadiusM = 500;

/// GPS radius to suggest "I'm outside" smart ping.
const double kSmartPingOutsideRadiusM = 150;

/// Delay after en-route before suggesting "On my way".
const Duration kSmartPingOnMyWayDelay = Duration(seconds: 30);

/// First-class driver → rider ping events (audit + FCM + timeline).
enum DriverPingType {
  onMyWay('on_my_way'),
  outside('outside'),
  arrived('arrived'),
  runningLate('running_late'),
  trafficDelay('traffic_delay'),
  cantFindRider('cant_find_rider'),
  thanks('thanks');

  const DriverPingType(this.apiKind);
  final String apiKind;

  /// Immutable audit event (`ride_audit_log.event`).
  String get auditEvent => 'driver.ping_$apiKind';

  /// Delivered lifecycle event appended after FCM success.
  String get auditDeliveredEvent => '$auditEvent.delivered';

  /// Rider opened ping in foreground (future / optional client).
  String get auditOpenedEvent => '$auditEvent.opened';

  /// Notification category for FCM + in-app routing.
  String get notificationCategory => 'driver_ping_$apiKind';

  /// Legacy HTTP nudge alias (on_my_way only).
  String? get legacyNudgeKind {
    switch (this) {
      case DriverPingType.onMyWay:
        return 'nearby';
      case DriverPingType.outside:
        return 'outside';
      default:
        return null;
    }
  }

  static DriverPingType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == 'nearby') return DriverPingType.onMyWay;
    for (final t in DriverPingType.values) {
      if (t.apiKind == normalized) return t;
    }
    if (normalized.startsWith('driver_ping_')) {
      return tryParse(normalized.replaceFirst('driver_ping_', ''));
    }
    return null;
  }

  static bool isPingCategory(String? category) {
    final c = (category ?? '').toLowerCase();
    return c.contains('driver_ping') ||
        c.contains('driver_nearby') ||
        c.contains('ride_nudge');
  }
}

/// Delivery lifecycle for pings (audit metadata + support).
enum DriverPingDeliveryState {
  queued('queued'),
  sent('sent'),
  delivered('delivered'),
  opened('opened'),
  failed('failed'),
  expired('expired');

  const DriverPingDeliveryState(this.apiValue);
  final String apiValue;
}

/// Ride phase for communication UI.
enum DriverRideCommunicationPhase {
  enRouteToPickup,
  atPickup,
  inProgress,
}

/// Context-aware quick actions (reduces choices while driving).
class DriverCommunicationContext {
  const DriverCommunicationContext({
    required this.quickPings,
    this.nearPickup = false,
  });

  final List<DriverPingType> quickPings;
  final bool nearPickup;
}

/// Resolves which pings to show — not every action all the time.
DriverCommunicationContext resolveCommunicationContext({
  required DriverRideCommunicationPhase phase,
  double? distanceToPickupM,
}) {
  switch (phase) {
    case DriverRideCommunicationPhase.enRouteToPickup:
      final nearPickup = distanceToPickupM != null &&
          distanceToPickupM <= kCommunicationNearPickupRadiusM;
      if (nearPickup) {
        return const DriverCommunicationContext(
          nearPickup: true,
          quickPings: [
            DriverPingType.outside,
            DriverPingType.arrived,
            DriverPingType.cantFindRider,
          ],
        );
      }
      return const DriverCommunicationContext(
        quickPings: [
          DriverPingType.onMyWay,
          DriverPingType.runningLate,
        ],
      );
    case DriverRideCommunicationPhase.atPickup:
      return const DriverCommunicationContext(
        nearPickup: true,
        quickPings: [
          DriverPingType.outside,
          DriverPingType.arrived,
          DriverPingType.cantFindRider,
        ],
      );
    case DriverRideCommunicationPhase.inProgress:
      return const DriverCommunicationContext(
        quickPings: [
          DriverPingType.runningLate,
          DriverPingType.trafficDelay,
        ],
      );
  }
}

/// Smart ping suggestions (one-tap, GPS/time assisted).
enum DriverSmartPingSuggestion {
  onMyWay,
  outside,
}

DriverSmartPingSuggestion? resolveSmartPingSuggestion({
  required DriverRideCommunicationPhase phase,
  required Duration enRouteDuration,
  required double? distanceToPickupM,
  required bool onMyWayAlreadySent,
  required bool outsideAlreadySent,
  required bool onMyWayDismissed,
  required bool outsideDismissed,
}) {
  if (phase == DriverRideCommunicationPhase.inProgress) return null;

  final nearOutside = distanceToPickupM != null &&
      distanceToPickupM <= kSmartPingOutsideRadiusM;

  if ((phase == DriverRideCommunicationPhase.atPickup || nearOutside) &&
      !outsideAlreadySent &&
      !outsideDismissed) {
    return DriverSmartPingSuggestion.outside;
  }

  if (phase == DriverRideCommunicationPhase.enRouteToPickup &&
      !nearOutside &&
      enRouteDuration >= kSmartPingOnMyWayDelay &&
      !onMyWayAlreadySent &&
      !onMyWayDismissed) {
    return DriverSmartPingSuggestion.onMyWay;
  }

  return null;
}

DriverPingType pingTypeForSmartSuggestion(DriverSmartPingSuggestion s) {
  switch (s) {
    case DriverSmartPingSuggestion.onMyWay:
      return DriverPingType.onMyWay;
    case DriverSmartPingSuggestion.outside:
      return DriverPingType.outside;
  }
}
