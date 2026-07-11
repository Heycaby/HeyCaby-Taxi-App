import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/constants/rider_rides_status_contract.dart';
import 'package:heycaby_rider/providers/near_term_ride_request_provider.dart';

void main() {
  test('upcoming and history cover every ride lifecycle status', () {
    const lifecycleStatuses = <String>{
      'pending',
      'bidding',
      'assigned',
      'accepted',
      'driver_found',
      'driver_en_route',
      'driver_arrived',
      'in_progress',
      'completed',
      'cancelled',
      'expired',
      'no_driver',
      'declined',
    };

    expect(
      riderUpcomingRideStatuses.intersection(riderHistoryRideStatuses),
      isEmpty,
    );
    expect(
      riderUpcomingRideStatuses.union(riderHistoryRideStatuses),
      lifecycleStatuses,
    );
  });

  test('cancelled history includes every unsuccessful terminal state', () {
    expect(
      riderCancelledHistoryStatuses,
      {'cancelled', 'expired', 'no_driver', 'declined'},
    );
  });

  test('accepted future scheduled ride remains upcoming, not live', () {
    final ride = NearTermRideSnapshot(
      id: 'scheduled',
      status: 'accepted',
      pickupAddress: 'Pickup',
      destinationAddress: 'Destination',
      scheduledPickupAt: DateTime.now().add(const Duration(hours: 2)),
      bookingMode: 'scheduled',
      createdAt: DateTime.now(),
    );

    expect(ride.isLiveRide, isFalse);
  });
}
