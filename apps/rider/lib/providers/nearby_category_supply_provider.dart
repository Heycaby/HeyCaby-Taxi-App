import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rider_vehicle_category.dart';
import '../services/nearby_supply_service.dart';
import 'booking_provider.dart';

/// Live-ish supply per category near [BookingState.pickup].
final nearbyCategorySupplyProvider = FutureProvider.autoDispose<
    Map<RiderVehicleCategory, CategorySupplySnapshot>>((ref) async {
  final booking = ref.watch(bookingProvider);
  final pickup = booking.pickup;
  if (pickup == null) {
    return {
      for (final c in RiderVehicleCategory.values)
        c: CategorySupplySnapshot.empty(c),
    };
  }
  final fullRoute =
      booking.pickup != null && booking.destination != null;
  return NearbySupplyService.loadForPickup(
    pickup: pickup,
    destination: booking.destination,
    returnTripFareEstimatesEnabled:
        fullRoute && booking.returnTripFareEstimatesEnabled,
  );
});
