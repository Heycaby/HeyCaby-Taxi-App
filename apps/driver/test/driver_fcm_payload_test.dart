import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/services/driver_fcm_payload.dart';

void main() {
  group('DriverFcmPayload', () {
    test('reads explicit category from data', () {
      final payload = DriverFcmPayload.fromData({
        'category': 'incoming_ride',
        'ride_request_id': 'ride-1',
        'screen': 'incoming',
      });
      expect(payload.effectiveCategory, 'incoming_ride');
      expect(payload.rideRequestId, 'ride-1');
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
  });
}
