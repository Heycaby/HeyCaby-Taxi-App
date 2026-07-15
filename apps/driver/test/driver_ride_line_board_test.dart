import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/models/driver_ride_line_board.dart';

void main() {
  test('DriverRideLineSlot routeLabel prefers zone names', () {
    const slot = DriverRideLineSlot(
      rideId: 'r1',
      statusLabel: 'After drop-off',
      pickupZoneName: 'Schiphol',
      destinationZoneName: 'Centrum',
      fareEuros: 42.5,
    );
    expect(slot.routeLabel, 'Schiphol → Centrum');
    expect(slot.fareLabel, '€42.50');
  });

  test('DriverMissedOpportunity parses RPC row', () {
    final item = DriverMissedOpportunity.fromJson({
      'id': 'm1',
      'missed_at': '2026-07-14T10:00:00Z',
      'pickup_zone_name': 'Rotterdam',
      'destination_zone_name': 'Amsterdam',
      'offered_fare': 28,
    });
    expect(item.routeLabel, 'Rotterdam → Amsterdam');
    expect(item.fareLabel, '€28.00');
  });
}
