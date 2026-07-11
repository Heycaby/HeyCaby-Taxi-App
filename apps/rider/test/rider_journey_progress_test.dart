import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/utils/rider_journey_progress.dart';

void main() {
  group('RiderJourneyProgress', () {
    test('driver matched before on-my-way stays at step 0', () {
      final progress = RiderJourneyProgress.compute(
        status: 'driver_found',
        driverOnMyWay: false,
      );
      expect(progress.stepIndex, 0);
      expect(progress.showLiveTrack, false);
    });

    test('on-my-way advances to en-route with live track', () {
      final progress = RiderJourneyProgress.compute(
        status: 'accepted',
        driverOnMyWay: true,
        driverLat: 52.37,
        driverLng: 4.90,
        pickupLat: 52.36,
        pickupLng: 4.89,
        enRouteBaselineKm: 2.0,
      );
      expect(progress.stepIndex, 1);
      expect(progress.showLiveTrack, true);
      expect(progress.trackProgress, greaterThan(0));
      expect(progress.trackProgress, lessThanOrEqualTo(1));
    });

    test('timelineIncludesOnMyWay detects ping audit rows', () {
      expect(
        RiderJourneyProgress.timelineIncludesOnMyWay(const [
          {'event': 'driver.ping_on_my_way'},
        ]),
        isTrue,
      );
      expect(
        RiderJourneyProgress.timelineIncludesOnMyWay(const [
          {'event': 'driver.ping_outside'},
        ]),
        isFalse,
      );
    });

    test('driver_en_route always shows live track', () {
      final progress = RiderJourneyProgress.compute(
        status: 'driver_en_route',
        driverOnMyWay: false,
      );
      expect(progress.stepIndex, 1);
      expect(progress.showLiveTrack, true);
    });
  });
}
