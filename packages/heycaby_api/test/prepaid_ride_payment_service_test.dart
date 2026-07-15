import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';

void main() {
  test('prepaid payment model maps backend state without calculating money', () {
    final payment = PrepaidRidePayment.fromJson(<String, dynamic>{
      'id': 'payment-1',
      'state': 'paid',
      'amount_cents': 1234,
      'currency': 'EUR',
      'checkout_url': 'https://www.mollie.com/checkout/test',
      'paid_at': '2026-07-14T12:00:00Z',
    });

    expect(payment.id, 'payment-1');
    expect(payment.amountCents, 1234);
    expect(payment.isPaid, isTrue);
    expect(payment.paidAt, isNotNull);
  });

  test('driver connection result remains not-ready unless backend says true', () {
    final result = DriverMollieConnectResult.fromRaw(<String, dynamic>{
      'ok': true,
      'status': 'onboarding',
      'can_receive_prepaid_rides': false,
    });

    expect(result.ok, isTrue);
    expect(result.canReceivePrepaidRides, isFalse);
  });
}
