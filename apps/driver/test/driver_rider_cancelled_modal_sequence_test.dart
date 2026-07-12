import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/providers/driver_state_provider.dart';
import 'package:heycaby_driver/utils/driver_rider_cancelled_flow.dart';

void main() {
  const rideId = '11111111-1111-4111-8111-111111111111';

  test('active accepted ride gets rating turn after cancellation', () {
    final state = const DriverData().copyWith(activeRideId: rideId);
    expect(
      shouldOfferRatingAfterRiderCancellation(
        rideId: rideId,
        state: state,
        path: '/driver',
      ),
      isTrue,
    );
  });

  test('rating route remains eligible after cancellation acknowledgement', () {
    expect(
      shouldOfferRatingAfterRiderCancellation(
        rideId: rideId,
        state: const DriverData(),
        path: '/driver/ride/rate/$rideId',
      ),
      isTrue,
    );
  });

  test('pre-accept incoming request does not ask for a rating', () {
    expect(
      shouldOfferRatingAfterRiderCancellation(
        rideId: rideId,
        state: const DriverData(),
        path: '/driver/ride/new/$rideId',
      ),
      isFalse,
    );
  });
}
