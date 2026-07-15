import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_ride_line_board.dart';
import '../providers/driver_state_provider.dart';
import 'driver_data_providers.dart';

DriverRideLineSlot? _slotFromRideRow(
  Map<String, dynamic> row, {
  required String statusLabel,
  bool isQueuedAfterCurrent = false,
}) {
  final id = (row['ride_id'] as String?) ?? (row['id'] as String?);
  if (id == null || id.isEmpty) return null;

  String? zoneName(dynamic nested) {
    if (nested is Map) return nested['name_display'] as String?;
    return null;
  }

  final fare = HeyCabyRideFare.resolveTotalEuroFromRow(row);

  return DriverRideLineSlot(
    rideId: id,
    statusLabel: statusLabel,
    pickupZoneName:
        (row['pickup_zone_name'] as String?) ?? zoneName(row['pickup_zone']),
    destinationZoneName: (row['destination_zone_name'] as String?) ??
        zoneName(row['destination_zone']),
    pickupAddress: row['pickup_address'] as String?,
    destinationAddress: row['destination_address'] as String?,
    fareEuros: fare,
    bookingMode: row['booking_mode'] as String?,
    isQueuedAfterCurrent: isQueuedAfterCurrent,
  );
}

String _nowStatusLabel(DriverAppState state) {
  return switch (state) {
    DriverAppState.arrived => DriverStrings.waiting,
    DriverAppState.inProgress => DriverStrings.navigate,
    DriverAppState.completingRide => DriverStrings.rideDetails,
    DriverAppState.assigned => DriverStrings.navigateToPickup,
    _ => DriverStrings.homeActiveRideTitle,
  };
}

/// Ride line board: NOW + NEXT + open invite summary (no ringing UI).
final driverRideLineProvider = FutureProvider<DriverRideLineBoard>((ref) async {
  final driver = ref.watch(driverStateProvider);
  final driverId = await ref.watch(driverIdProvider.future);
  if (driverId == null) return DriverRideLineBoard.empty;

  final service = ref.read(driverDataServiceProvider);
  DriverRideLineSlot? now;
  DriverRideLineSlot? next;

  if (driver.activeRideId != null) {
    final row = await service.fetchRideLineRideRow(driver.activeRideId!);
    if (row != null) {
      now = _slotFromRideRow(
        row,
        statusLabel: _nowStatusLabel(driver.appState),
      );
    } else {
      now = DriverRideLineSlot(
        rideId: driver.activeRideId!,
        statusLabel: _nowStatusLabel(driver.appState),
        pickupAddress: driver.pickupAddress,
        destinationAddress: driver.destinationAddress,
      );
    }
  }

  final queued = await service.fetchNextRideQueue(
    activeRideId: driver.activeRideId,
  );
  if (queued != null) {
    next = _slotFromRideRow(
      queued,
      statusLabel: DriverStrings.rideLineNextAfterDropOff,
      isQueuedAfterCurrent: true,
    );
  }

  final openInvites = await service.getAvailableRidesNow();
  final openCount = openInvites.length;
  double? topFare;
  for (final ride in openInvites) {
    final fare = ride.estimatedFare;
    if (fare == null) continue;
    if (topFare == null || fare > topFare) topFare = fare;
  }

  return DriverRideLineBoard(
    now: now,
    next: next,
    open: DriverRideLineOpenSummary(
      count: openCount,
      topFareEuros: topFare,
    ),
  );
});

final driverMissedSummaryProvider =
    FutureProvider<DriverMissedOpportunitySummary>((ref) async {
  return ref.read(driverDataServiceProvider).fetchMissedOpportunitiesSummary();
});

final driverMissedOpportunitiesProvider =
    FutureProvider<List<DriverMissedOpportunity>>((ref) async {
  return ref.read(driverDataServiceProvider).fetchMissedOpportunities();
});
