import 'package:flutter/foundation.dart';

/// Driver ride line: NOW (active) + NEXT (queued after drop-off) + open summary.
@immutable
class DriverRideLineSlot {
  const DriverRideLineSlot({
    required this.rideId,
    required this.statusLabel,
    this.pickupZoneName,
    this.destinationZoneName,
    this.pickupAddress,
    this.destinationAddress,
    this.fareEuros,
    this.bookingMode,
    this.isQueuedAfterCurrent = false,
  });

  final String rideId;
  final String statusLabel;
  final String? pickupZoneName;
  final String? destinationZoneName;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? fareEuros;
  final String? bookingMode;
  final bool isQueuedAfterCurrent;

  String get routeLabel {
    final from = displayRideLineZone(pickupZoneName, pickupAddress);
    final to = displayRideLineZone(destinationZoneName, destinationAddress);
    return '$from → $to';
  }

  String? get fareLabel {
    if (fareEuros == null) return null;
    return '€${fareEuros!.toStringAsFixed(2)}';
  }
}

String displayRideLineZone(String? zone, String? address) {
  final z = zone?.trim();
  if (z != null && z.isNotEmpty) return z;
  final a = address?.trim();
  if (a == null || a.isEmpty) return '—';
  final first = a.split(',').first.trim();
  return first.isEmpty ? '—' : first;
}

@immutable
class DriverRideLineOpenSummary {
  const DriverRideLineOpenSummary({
    this.count = 0,
    this.topFareEuros,
  });

  final int count;
  final double? topFareEuros;

  bool get hasOpen => count > 0;
}

@immutable
class DriverRideLineBoard {
  const DriverRideLineBoard({
    this.now,
    this.next,
    this.open = const DriverRideLineOpenSummary(),
  });

  final DriverRideLineSlot? now;
  final DriverRideLineSlot? next;
  final DriverRideLineOpenSummary open;

  bool get hasNow => now != null;
  bool get hasNext => next != null;
  bool get hasContent => hasNow || hasNext || open.hasOpen;

  static const empty = DriverRideLineBoard();
}

@immutable
class DriverMissedOpportunitySummary {
  const DriverMissedOpportunitySummary({
    this.countToday = 0,
    this.fareTotalToday = 0,
  });

  final int countToday;
  final double fareTotalToday;

  bool get hasMissed => countToday > 0;
}

@immutable
class DriverMissedOpportunity {
  const DriverMissedOpportunity({
    required this.id,
    required this.missedAt,
    this.pickupZoneName,
    this.destinationZoneName,
    this.offeredFare,
    this.rideRequestId,
  });

  final String id;
  final DateTime missedAt;
  final String? pickupZoneName;
  final String? destinationZoneName;
  final double? offeredFare;
  final String? rideRequestId;

  String get routeLabel {
    final from = displayRideLineZone(pickupZoneName, null);
    final to = displayRideLineZone(destinationZoneName, null);
    return '$from → $to';
  }

  String? get fareLabel {
    if (offeredFare == null) return null;
    return '€${offeredFare!.toStringAsFixed(2)}';
  }

  factory DriverMissedOpportunity.fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    return DriverMissedOpportunity(
      id: (j['id'] as String?) ?? '',
      missedAt: parse(j['missed_at']) ?? DateTime.now().toUtc(),
      pickupZoneName: j['pickup_zone_name'] as String?,
      destinationZoneName: j['destination_zone_name'] as String?,
      offeredFare: (j['offered_fare'] as num?)?.toDouble(),
      rideRequestId: j['ride_request_id'] as String?,
    );
  }
}
