import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../providers/driver_data_providers.dart';
import '../utils/driver_ride_line_refresh.dart';

/// Records a missed invite for the FOMO ledger (best-effort).
Future<void> recordDriverMissedOpportunity({
  required WidgetRef ref,
  required String rideRequestId,
  Map<String, dynamic>? rideRow,
}) async {
  if (rideRequestId.trim().isEmpty) return;

  var row = rideRow;
  if (row == null) {
    try {
      final fetched = await ref
          .read(driverDataServiceProvider)
          .fetchRideLineRideRow(rideRequestId);
      row = fetched;
    } catch (_) {
      row = null;
    }
  }

  String? zoneName(dynamic nested) {
    if (nested is Map) return nested['name_display'] as String?;
    return null;
  }

  final pickupZone = row == null
      ? null
      : zoneName(row['pickup_zone']) ??
          (row['pickup_zone_name'] as String?);
  final destZone = row == null
      ? null
      : zoneName(row['destination_zone']) ??
          (row['destination_zone_name'] as String?);
  final fare = row == null ? null : HeyCabyRideFare.resolveTotalEuroFromRow(row);

  await ref.read(driverDataServiceProvider).recordMissedOpportunity(
        rideRequestId: rideRequestId,
        pickupZoneName: pickupZone,
        destinationZoneName: destZone,
        offeredFare: fare,
      );
  invalidateDriverRideLine(ref);
}
