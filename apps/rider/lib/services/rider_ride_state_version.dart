import 'package:flutter/foundation.dart';

import 'rider_ride_lifecycle_snapshot.dart';

/// Monotonic ride state version derived from `ride_requests.updated_at`.
///
/// Prevents duplicate, stale, and out-of-order Live Activity updates.
abstract final class RiderRideStateVersionGate {
  static final Map<String, int> _lastApplied = {};

  /// Grace/countdown ticks reuse the same backend version — always allow.
  static bool isGraceTickSource(String source) =>
      source == 'grace_tick' || source == 'driver_location';

  static bool shouldApply({
    required String rideRequestId,
    required int incomingVersion,
    required String source,
  }) {
    if (isGraceTickSource(source)) return true;
    if (incomingVersion <= 0) return true;
    final last = _lastApplied[rideRequestId] ?? 0;
    if (incomingVersion < last) {
      if (kDebugMode) {
        debugPrint(
          '[RideLifecycleEngine] skip stale ride=$rideRequestId '
          'incomingVersion=$incomingVersion last=$last source=$source',
        );
      }
      return false;
    }
    if (incomingVersion == last) {
      if (kDebugMode) {
        debugPrint(
          '[RideLifecycleEngine] skip duplicate ride=$rideRequestId '
          'version=$incomingVersion source=$source',
        );
      }
      return false;
    }
    return true;
  }

  static void markApplied({
    required String rideRequestId,
    required int version,
    required String source,
  }) {
    if (isGraceTickSource(source)) return;
    if (version <= 0) return;
    _lastApplied[rideRequestId] = version;
  }

  static void reset(String rideRequestId) {
    _lastApplied.remove(rideRequestId);
  }

  static void resetAll() => _lastApplied.clear();
}

/// Extract ride id from FCM / push data maps.
String? rideRequestIdFromPushData(Map<String, dynamic> data) {
  for (final key in const [
    'ride_request_id',
    'rideRequestId',
    'ride_id',
    'rideId',
    'request_id',
  ]) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Presentation fields needed to build a Live Activity payload.
class RideStatePresentation {
  const RideStatePresentation({
    this.driverName = '',
    this.vehicleLabel = '',
    this.vehiclePlate = '',
    this.pickupSummary = '',
    this.destinationSummary = '',
    this.rideCreatedAt,
    this.driversNotified = 0,
    this.driverKmToPickup,
    this.etaMinutes,
    this.paymentMethodLabel,
  });

  final String driverName;
  final String vehicleLabel;
  final String vehiclePlate;
  final String pickupSummary;
  final String destinationSummary;
  final DateTime? rideCreatedAt;
  final int driversNotified;
  final double? driverKmToPickup;
  final int? etaMinutes;
  final String? paymentMethodLabel;

  RideStatePresentation copyWith({
    String? driverName,
    String? vehicleLabel,
    String? vehiclePlate,
    String? pickupSummary,
    String? destinationSummary,
    DateTime? rideCreatedAt,
    int? driversNotified,
    double? driverKmToPickup,
    int? etaMinutes,
    String? paymentMethodLabel,
  }) {
    return RideStatePresentation(
      driverName: driverName ?? this.driverName,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      pickupSummary: pickupSummary ?? this.pickupSummary,
      destinationSummary: destinationSummary ?? this.destinationSummary,
      rideCreatedAt: rideCreatedAt ?? this.rideCreatedAt,
      driversNotified: driversNotified ?? this.driversNotified,
      driverKmToPickup: driverKmToPickup ?? this.driverKmToPickup,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
    );
  }
}

/// DB status for in-app providers — never synthetic LA-only phases like `driver_nearby`.
String inferRideProviderStatus(RiderRideLifecycleSnapshot snapshot) {
  final raw = (snapshot.status ?? '').trim().toLowerCase();
  final ps = (snapshot.paymentStatus ?? '').trim().toLowerCase();
  if (ps == 'paid') return 'completed';
  if (raw == 'completed' || snapshot.completedAt != null) return 'completed';
  if (raw == 'in_progress' || snapshot.startedAt != null) return 'in_progress';
  if (snapshot.driverArrivedAt != null ||
      raw == 'driver_arrived' ||
      raw == 'arrived') {
    return 'driver_arrived';
  }
  if (raw.isNotEmpty) return raw;
  if (snapshot.driverId != null && snapshot.driverId!.isNotEmpty) {
    return 'accepted';
  }
  return '';
}

/// Build presentation hints from a fetched `ride_requests` row (background-safe).
RideStatePresentation presentationFromRow(Map<String, dynamic> row) {
  DateTime? createdAt;
  final createdRaw = row['created_at'];
  if (createdRaw is DateTime) {
    createdAt = createdRaw;
  } else if (createdRaw != null) {
    createdAt = DateTime.tryParse(createdRaw.toString());
  }
  return RideStatePresentation(
    pickupSummary: row['pickup_address']?.toString() ?? '',
    destinationSummary: row['destination_address']?.toString() ?? '',
    rideCreatedAt: createdAt,
  );
}
