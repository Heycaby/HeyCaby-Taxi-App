import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';

void main() {
  test('verification snapshot maps backend proof without deriving policy', () {
    final snapshot = RideVerificationSnapshot.fromRaw(<String, dynamic>{
      'ok': true,
      'protected': true,
      'arrival_verified': true,
      'boarding_verified': false,
      'completion_verified': false,
      'risk_status': 'clear',
      'boarding_pin': '482193',
      'boarding_pin_expires_at': '2026-07-15T10:30:00Z',
      'waiting_timer_started_at': '2026-07-15T10:00:00Z',
    });

    expect(snapshot.isProtected, isTrue);
    expect(snapshot.arrivalVerified, isTrue);
    expect(snapshot.boardingVerified, isFalse);
    expect(snapshot.boardingPin, '482193');
    expect(snapshot.paymentEligibleAt, isNull);
  });

  test('verification snapshot fails closed on non-canonical response', () {
    expect(
      () => RideVerificationSnapshot.fromRaw(<String, dynamic>{
        'ok': false,
        'error': 'not_authorized',
      }),
      throwsA(
        isA<RideVerificationException>().having(
          (error) => error.code,
          'code',
          'not_authorized',
        ),
      ),
    );
  });
}
