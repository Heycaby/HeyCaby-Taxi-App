/// Parsed active-ride route edits shared by rider and driver clients.
class ActiveRideRouteStop {
  const ActiveRideRouteStop({
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String address;
  final double lat;
  final double lng;

  static List<ActiveRideRouteStop> parseStops(dynamic raw) {
    if (raw is! List) return const [];
    final stops = <ActiveRideRouteStop>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final address = (entry['address'] as String?)?.trim() ?? '';
      final lat = (entry['lat'] as num?)?.toDouble();
      final lng = (entry['lng'] as num?)?.toDouble();
      if (address.isEmpty || lat == null || lng == null) continue;
      stops.add(ActiveRideRouteStop(address: address, lat: lat, lng: lng));
    }
    return stops;
  }
}

/// Rider-submitted route edit awaiting driver approval.
class PendingRouteChange {
  const PendingRouteChange({
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    this.stops = const [],
    this.requestedAt,
  });

  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final List<ActiveRideRouteStop> stops;
  final DateTime? requestedAt;

  static PendingRouteChange? parse(dynamic raw) {
    if (raw is! Map) return null;
    final address = (raw['destination_address'] as String?)?.trim() ?? '';
    final lat = (raw['destination_lat'] as num?)?.toDouble();
    final lng = (raw['destination_lng'] as num?)?.toDouble();
    if (address.isEmpty || lat == null || lng == null) return null;
    return PendingRouteChange(
      destinationAddress: address,
      destinationLat: lat,
      destinationLng: lng,
      stops: ActiveRideRouteStop.parseStops(raw['stops']),
      requestedAt: DateTime.tryParse(raw['requested_at']?.toString() ?? ''),
    );
  }

  /// First stop address that is not already on the confirmed route.
  String? firstNewStopLabel(ActiveRideRouteState confirmed) {
    for (final stop in stops) {
      final duplicate = confirmed.stops.any(
        (existing) =>
            existing.address.trim() == stop.address.trim() ||
            (_coordsNear(existing.lat, existing.lng, stop.lat, stop.lng)),
      );
      if (!duplicate) {
        return stop.address.split(',').first.trim().isEmpty
            ? stop.address
            : stop.address.split(',').first.trim();
      }
    }
    if (confirmed.destinationAddress.trim() != destinationAddress.trim()) {
      final short = destinationAddress.split(',').first.trim();
      return short.isEmpty ? destinationAddress : short;
    }
    return stops.isNotEmpty ? stops.last.address : destinationAddress;
  }

  String dedupeKey() {
    final stopKey = stops
        .map((s) => '${s.lat.toStringAsFixed(5)}:${s.lng.toStringAsFixed(5)}')
        .join('|');
    return '${destinationLat.toStringAsFixed(5)}:'
        '${destinationLng.toStringAsFixed(5)}:$stopKey';
  }
}

bool _coordsNear(double aLat, double aLng, double bLat, double bLng) {
  const epsilon = 0.00005;
  return (aLat - bLat).abs() <= epsilon && (aLng - bLng).abs() <= epsilon;
}

class ActiveRideRouteState {
  const ActiveRideRouteState({
    required this.destinationAddress,
    this.destinationLat,
    this.destinationLng,
    this.bookedDestinationAddress,
    this.bookedDestinationLat,
    this.bookedDestinationLng,
    this.stops = const [],
    this.routeRevision = 0,
    this.pendingRouteChange,
  });

  final String destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final String? bookedDestinationAddress;
  final double? bookedDestinationLat;
  final double? bookedDestinationLng;
  final List<ActiveRideRouteStop> stops;
  final int routeRevision;
  final PendingRouteChange? pendingRouteChange;

  factory ActiveRideRouteState.fromRideRow(Map<String, dynamic> row) {
    return ActiveRideRouteState(
      destinationAddress: (row['destination_address'] as String?)?.trim() ?? '',
      destinationLat: (row['destination_lat'] as num?)?.toDouble(),
      destinationLng: (row['destination_lng'] as num?)?.toDouble(),
      bookedDestinationAddress:
          (row['booked_destination_address'] as String?)?.trim(),
      bookedDestinationLat: (row['booked_destination_lat'] as num?)?.toDouble(),
      bookedDestinationLng: (row['booked_destination_lng'] as num?)?.toDouble(),
      stops: ActiveRideRouteStop.parseStops(row['route_stops']),
      routeRevision: (row['route_revision'] as num?)?.toInt() ?? 0,
      pendingRouteChange: PendingRouteChange.parse(row['pending_route_change']),
    );
  }

  bool get destinationChanged {
    final booked = bookedDestinationAddress?.trim();
    if (booked == null || booked.isEmpty) return false;
    final current = destinationAddress.trim();
    if (booked != current) return true;
    if (bookedDestinationLat != null &&
        bookedDestinationLng != null &&
        destinationLat != null &&
        destinationLng != null) {
      return !_coordsNear(
        bookedDestinationLat!,
        bookedDestinationLng!,
        destinationLat!,
        destinationLng!,
      );
    }
    return false;
  }

  int get stopCount => stops.length;

  bool get hasPendingRouteChange => pendingRouteChange != null;

  bool get hasRouteEdits => destinationChanged || stopCount > 0;
}
