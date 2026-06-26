import '../providers/driver_state_provider.dart';

/// Maps server `drivers.status` to client availability (no active ride).
DriverAppState driverAvailabilityFromServerStatus(String? status) {
  switch (status) {
    case 'available':
    case 'on_ride':
      return DriverAppState.onlineAvailable;
    case 'on_break':
      return DriverAppState.onBreak;
    case 'offline':
    default:
      return DriverAppState.offline;
  }
}

/// Maps `ride_requests.status` to in-ride client state.
DriverAppState driverAppStateFromRideStatus(String? status) {
  switch (status) {
    case 'driver_arrived':
      return DriverAppState.arrived;
    case 'in_progress':
      return DriverAppState.inProgress;
    case 'accepted':
    case 'assigned':
    default:
      return DriverAppState.assigned;
  }
}

/// Route to resume an in-progress ride after cold start (Program 3B).
String rideRestoreRoute(DriverAppState appState, String rideId) {
  switch (appState) {
    case DriverAppState.arrived:
      return '/driver/ride/pickup/$rideId';
    case DriverAppState.inProgress:
      return '/driver/ride/progress/$rideId';
    case DriverAppState.completingRide:
      return '/driver/ride/complete/$rideId';
    case DriverAppState.assigned:
    case DriverAppState.acceptingRide:
    case DriverAppState.reviewingRequest:
    case DriverAppState.completed:
      return '/driver/ride/active/$rideId';
    default:
      return '/driver/ride/active/$rideId';
  }
}

/// Terminal ride statuses — not restored as active.
bool isRestorableRideStatus(String? status) {
  if (status == null || status.isEmpty) return false;
  const restorable = {
    'accepted',
    'assigned',
    'driver_arrived',
    'in_progress',
  };
  return restorable.contains(status);
}

/// Parsed active ride row for Riverpod restore.
class DriverActiveRideSnapshot {
  const DriverActiveRideSnapshot({
    required this.rideId,
    required this.appState,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.bookingMode,
    required this.paymentMethod,
    required this.riderContactName,
  });

  final String rideId;
  final DriverAppState appState;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final String? bookingMode;
  final String? paymentMethod;
  final String? riderContactName;

  factory DriverActiveRideSnapshot.fromRow(Map<String, dynamic> row) {
    final rideId = row['id'] as String;
    final status = row['status'] as String?;
    return DriverActiveRideSnapshot(
      rideId: rideId,
      appState: driverAppStateFromRideStatus(status),
      pickupAddress: row['pickup_address'] as String?,
      pickupLat: (row['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (row['pickup_lng'] as num?)?.toDouble(),
      destinationAddress: row['destination_address'] as String?,
      destinationLat: (row['destination_lat'] as num?)?.toDouble(),
      destinationLng: (row['destination_lng'] as num?)?.toDouble(),
      bookingMode: row['booking_mode'] as String?,
      paymentMethod: _paymentMethodFromRow(row),
      riderContactName: row['pickup_contact_name'] as String?,
    );
  }

  static String? _paymentMethodFromRow(Map<String, dynamic> row) {
    final direct = row['payment_method'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    final methods = row['payment_methods'];
    if (methods is List && methods.isNotEmpty) {
      return methods.first?.toString();
    }
    return null;
  }

  String get restoreRoute => rideRestoreRoute(appState, rideId);
}

/// Result of server operational restore.
class DriverOperationalRestoreSnapshot {
  const DriverOperationalRestoreSnapshot({
    required this.availabilityState,
    this.activeRide,
    this.serverDriverStatus,
  });

  final DriverAppState availabilityState;
  final DriverActiveRideSnapshot? activeRide;
  final String? serverDriverStatus;

  DriverAppState get effectiveAppState =>
      activeRide?.appState ?? availabilityState;

  String? get navigationRoute => activeRide?.restoreRoute;
}
