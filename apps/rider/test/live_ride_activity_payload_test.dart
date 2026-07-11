import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/models/live_ride_activity_phase.dart';
import 'package:heycaby_rider/models/ride_waiting_info.dart';
import 'package:heycaby_rider/services/live_ride_activity_payload.dart';
import 'package:heycaby_rider/services/rider_ride_lifecycle_snapshot.dart';

void main() {
  group('RiderRideLifecycleSnapshot.resolveEffectiveStatus', () {
    test('uses driver_arrived_at when status still accepted', () {
      final snap = RiderRideLifecycleSnapshot.fromRow(
        {
          'status': 'accepted',
          'driver_id': 'd1',
          'driver_arrived_at': DateTime.now().toUtc().toIso8601String(),
          'waiting_grace_seconds': 120,
        },
        rideRequestId: 'r1',
      );
      expect(snap.resolveEffectiveStatus(), 'driver_arrived');
    });

    test('uses started_at when status still driver_arrived', () {
      final snap = RiderRideLifecycleSnapshot.fromRow(
        {
          'status': 'driver_arrived',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        },
        rideRequestId: 'r1',
      );
      expect(snap.resolveEffectiveStatus(), 'in_progress');
    });

    test('near_pickup_notified_at maps to driver_nearby', () {
      final snap = RiderRideLifecycleSnapshot.fromRow(
        {
          'status': 'driver_en_route',
          'near_pickup_notified_at': DateTime.now().toUtc().toIso8601String(),
        },
        rideRequestId: 'r1',
      );
      expect(snap.resolveEffectiveStatus(), 'driver_nearby');
    });

    test('payment paid maps to payment_confirmed', () {
      final snap = RiderRideLifecycleSnapshot.fromRow(
        {
          'status': 'completed',
          'payment_status': 'paid',
        },
        rideRequestId: 'r1',
      );
      expect(snap.resolveEffectiveStatus(), 'payment_confirmed');
    });
  });

  group('LiveRideActivityPayload.resolveActivePhase', () {
    test('maps en route with distance to nearby', () {
      final phase = LiveRideActivityPayload.resolveActivePhase(
        rideStatus: 'driver_en_route',
        driverKmToPickup: 0.4,
      );
      expect(phase, LiveRideActivityPhase.nearby);
    });

    test('maps driver_nearby status', () {
      final phase = LiveRideActivityPayload.resolveActivePhase(
        rideStatus: 'driver_nearby',
      );
      expect(phase, LiveRideActivityPhase.nearby);
    });

    test('maps arrived in grace to outsideFreeWait', () {
      final arrived = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
      final info = RideWaitingInfo(
        arrivedAt: arrived,
        graceSeconds: 120,
        ratePerMinute: 0.40,
        frozenChargeableSeconds: 0,
        frozenFeeCents: 0,
        waived: false,
      );
      final phase = LiveRideActivityPayload.resolveActivePhase(
        rideStatus: 'driver_arrived',
        waitingInfo: info,
      );
      expect(phase, LiveRideActivityPhase.outsideFreeWait);
    });

    test('maps arrived after grace to outsidePaidWait', () {
      final arrived = DateTime.now().toUtc().subtract(const Duration(minutes: 3));
      final info = RideWaitingInfo(
        arrivedAt: arrived,
        graceSeconds: 120,
        ratePerMinute: 0.40,
        frozenChargeableSeconds: 0,
        frozenFeeCents: 0,
        waived: false,
      );
      final phase = LiveRideActivityPayload.resolveActivePhase(
        rideStatus: 'driver_arrived',
        waitingInfo: info,
      );
      expect(phase, LiveRideActivityPhase.outsidePaidWait);
    });

    test('completed without paid maps to paymentPending', () {
      final phase = LiveRideActivityPayload.resolveActivePhase(
        rideStatus: 'completed',
        paymentPending: true,
      );
      expect(phase, LiveRideActivityPhase.paymentPending);
    });
  });

  group('LiveRideActivityPayload.activeRide copy', () {
    test('nearby uses head downstairs next action', () {
      final payload = LiveRideActivityPayload.activeRide(
        rideStatus: 'driver_en_route',
        driverName: 'Ahmed',
        vehicleLabel: 'Black Tesla',
        plate: 'TX-22-NL',
        etaMinutes: 2,
        driverKmToPickup: 0.8,
      );
      expect(payload.phase, LiveRideActivityPhase.nearby);
      expect(payload.nextAction, 'Please head downstairs.');
      expect(payload.progressPercent, 60);
    });

    test('searching elapsed formats as minutes not seconds', () {
      final payload = LiveRideActivityPayload.searching(
        routeLine: 'A → B',
        elapsedSeconds: 583,
      );
      expect(payload.heroMetric, '10 min');
      expect(
        LiveRideActivityPayload.searching(
          routeLine: 'A',
          elapsedSeconds: 45,
        ).heroMetric,
        '1 min',
      );
    });

    test('searching payload includes driver count', () {
      final payload = LiveRideActivityPayload.searching(
        routeLine: 'A → B',
        driversNotified: 5,
      );
      final map = payload.toActivityMap();
      expect(map['phase'], 'searching');
      expect(map['progressPercent'], '15');
      expect(map['status'], contains('5 drivers'));
      expect(map['nextAction'], isNotEmpty);
    });
  });

  group('LiveRideActivityPhase.progressPercent', () {
    test('matches CTO spec anchors', () {
      expect(LiveRideActivityPhase.searching.progressPercent, 15);
      expect(LiveRideActivityPhase.nearby.progressPercent, 60);
      expect(LiveRideActivityPhase.outsideFreeWait.progressPercent, 70);
      expect(LiveRideActivityPhase.onTrip.progressPercent, 85);
      expect(LiveRideActivityPhase.paymentComplete.progressPercent, 100);
    });
  });
}
