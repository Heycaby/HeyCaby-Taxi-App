import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/services/driver_fcm_payload.dart';
import 'package:heycaby_driver/services/driver_notification_router.dart';

void main() {
  group('DriverFcmPayload', () {
    test('reads explicit category from data', () {
      final payload = DriverFcmPayload.fromData({
        'category': 'incoming_ride',
        'ride_request_id': 'ride-1',
        'ride_invite_id': 'invite-1',
        'expires_at': '2026-07-10T12:30:00Z',
        'screen': 'incoming',
      });
      expect(payload.effectiveCategory, 'incoming_ride');
      expect(payload.rideRequestId, 'ride-1');
      expect(payload.rideInviteId, 'invite-1');
      expect(payload.expiresAt, DateTime.utc(2026, 7, 10, 12, 30));
    });

    test('infers incoming_ride from screen', () {
      final payload = DriverFcmPayload.fromData({
        'ride_request_id': 'ride-2',
        'screen': 'incoming',
      });
      expect(payload.effectiveCategory, 'incoming_ride');
    });

    test('infers ride_phase from cancelled title', () {
      final payload = DriverFcmPayload.fromRemoteMessage(
        RemoteMessage(
          notification: const RemoteNotification(
            title: '⚠️ Rider cancelled the ride',
          ),
          data: const {'ride_request_id': 'ride-3'},
        ),
      );
      expect(payload.effectiveCategory, 'ride_phase');
      expect(payload.rideRequestId, 'ride-3');
    });

    test('infers chat from title prefix', () {
      final payload = DriverFcmPayload.fromRemoteMessage(
        RemoteMessage(
          notification: const RemoteNotification(title: '💬 [Rider]: Hi'),
          data: const {'ride_request_id': 'ride-4'},
        ),
      );
      expect(payload.effectiveCategory, 'chat');
    });

    test('reads session_revoked category', () {
      final payload = DriverFcmPayload.fromData({
        'category': 'session_revoked',
      });
      expect(payload.effectiveCategory, 'session_revoked');
    });

    test('Taxi Terug offer increases open the canonical posts board', () {
      final behavior = driverBehaviorForCategory('taxi_terug_offer_increased');
      expect(behavior, DriverNotificationBehavior.taxiTerug);
      expect(driverDeepLinkForBehavior(behavior), '/driver/taxi-thru');

      final handler =
          File('lib/services/driver_fcm_handler.dart').readAsStringSync();
      final listener = File('lib/widgets/driver_notifications_listener.dart')
          .readAsStringSync();
      for (final source in [handler, listener]) {
        expect(
          source,
          anyOf(
            contains("category == 'taxi_terug_offer_increased'"),
            contains("case 'taxi_terug_offer_increased'"),
          ),
        );
        expect(source, contains('driverTaxiThruRiderPostsProvider'));
        expect(source, contains('driverTaxiThruPostsCountProvider'));
      }
    });

    test('foreground and tapped invites share canonical backend validation',
        () {
      final handler =
          File('lib/services/driver_fcm_handler.dart').readAsStringSync();
      final mainSource = File('lib/main.dart').readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final coordinator = File(
        'lib/services/driver_incoming_ride_coordinator.dart',
      ).readAsStringSync();

      expect(
          handler, contains('DriverIncomingRideCoordinator.openIncomingRide'));
      expect(handler, isNot(contains('showIncomingRide(')));
      expect(mainSource, isNot(contains('FlutterCallkitIncoming')));
      expect(mainSource, isNot(contains('DriverCallkitService')));
      expect(pubspec, isNot(contains('flutter_callkit_incoming')));
      expect(manifest, isNot(contains('FOREGROUND_SERVICE_PHONE_CALL')));
      expect(manifest, isNot(contains('USE_FULL_SCREEN_INTENT')));
      expect(coordinator, contains(".from('ride_request_invites')"));
      expect(coordinator, contains("status != 'pending'"));
      expect(coordinator, contains('!expiresAt.isAfter'));
    });
  });
}
