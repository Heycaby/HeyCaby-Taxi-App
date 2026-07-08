import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/driver_state_provider.dart';
import '../widgets/driver_ride_flow_common.dart';

/// Parse ride pickup/destination from PostGIS columns when lat/lng are null.
void enrichDriverRideRequestCoords(Map<String, dynamic> row) {
  final pickupLat = (row['pickup_lat'] as num?)?.toDouble();
  final pickupLng = (row['pickup_lng'] as num?)?.toDouble();
  final destLat = (row['destination_lat'] as num?)?.toDouble();
  final destLng = (row['destination_lng'] as num?)?.toDouble();

  if (pickupLat == null || pickupLng == null) {
    final parsed = parseDriverRidePoint(row['pickup_coords']);
    if (parsed != null) {
      row['pickup_lat'] = parsed.$1;
      row['pickup_lng'] = parsed.$2;
    }
  }
  if (destLat == null || destLng == null) {
    final parsed = parseDriverRidePoint(row['destination_coords']);
    if (parsed != null) {
      row['destination_lat'] = parsed.$1;
      row['destination_lng'] = parsed.$2;
    }
  }
}

/// Returns `(lat, lng)` or null.
(double, double)? parseDriverRidePoint(dynamic raw) {
  if (raw == null) return null;

  if (raw is List && raw.length >= 2) {
    final lng = (raw[0] as num?)?.toDouble();
    final lat = (raw[1] as num?)?.toDouble();
    if (lat != null && lng != null) return (lat, lng);
    return null;
  }

  if (raw is Map) {
    final coords = raw['coordinates'];
    if (coords is List && coords.length >= 2) {
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat != null && lng != null) return (lat, lng);
    }
    return null;
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        return parseDriverRidePoint(decoded);
      } catch (_) {}
    }
    if (trimmed.startsWith('POINT(') && trimmed.endsWith(')')) {
      final inner = trimmed.substring(6, trimmed.length - 1).trim();
      final parts = inner.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        if (lat != null && lng != null) return (lat, lng);
      }
    }
    if (trimmed.length >= 50) {
      final hex = trimmed.startsWith('\\x')
          ? trimmed.substring(2)
          : trimmed.startsWith('0x')
              ? trimmed.substring(2)
              : trimmed;
      return _parseWkbHexPoint(hex);
    }
  }

  return null;
}

(double, double)? _parseWkbHexPoint(String hex) {
  try {
    final bytes = _hexDecode(hex);
    if (bytes.length < 21) return null;
    final isLittleEndian = bytes[0] == 1;
    final x = _readDouble(bytes, 5, isLittleEndian);
    final y = _readDouble(bytes, 13, isLittleEndian);
    if (x == null || y == null) return null;
    return (y, x);
  } catch (_) {
    return null;
  }
}

List<int> _hexDecode(String hex) {
  final bytes = <int>[];
  for (var i = 0; i + 1 < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

double? _readDouble(List<int> bytes, int offset, bool littleEndian) {
  if (offset + 8 > bytes.length) return null;
  final data = littleEndian
      ? bytes.sublist(offset, offset + 8)
      : bytes.sublist(offset, offset + 8).reversed.toList();
  return ByteData.sublistView(Uint8List.fromList(data))
      .getFloat64(0, Endian.little);
}

/// Load pickup/destination coordinates into [driverStateProvider] when missing.
Future<void> hydrateDriverRideCoordsIfNeeded(WidgetRef ref, String rideId) async {
  final driver = ref.read(driverStateProvider);
  final hasPickup =
      driverMapCoordIsValid(driver.pickupLat, driver.pickupLng);
  final hasDest = driverMapCoordIsValid(
    driver.destinationLat,
    driver.destinationLng,
  );
  if (hasPickup && hasDest) return;

  try {
    final row = await HeyCabySupabase.client
        .from('ride_requests')
        .select(
          'pickup_lat, pickup_lng, destination_lat, destination_lng, '
          'pickup_coords, destination_coords, '
          'pickup_address, destination_address',
        )
        .eq('id', rideId)
        .maybeSingle();
    if (row == null) return;

    final map = Map<String, dynamic>.from(row);
    enrichDriverRideRequestCoords(map);

    ref.read(driverStateProvider.notifier).patchRideCoords(
          pickupLat: hasPickup
              ? driver.pickupLat
              : (map['pickup_lat'] as num?)?.toDouble(),
          pickupLng: hasPickup
              ? driver.pickupLng
              : (map['pickup_lng'] as num?)?.toDouble(),
          destinationLat: hasDest
              ? driver.destinationLat
              : (map['destination_lat'] as num?)?.toDouble(),
          destinationLng: hasDest
              ? driver.destinationLng
              : (map['destination_lng'] as num?)?.toDouble(),
        );
  } catch (_) {
    // Map falls back to default camera when coords stay unavailable.
  }
}
