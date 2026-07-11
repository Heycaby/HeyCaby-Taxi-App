import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/widgets/driver_bank_transfer_sheet.dart';

void main() {
  test('parses complete server-configured bank transfer details', () {
    final details = DriverBankTransferDetails.fromBillingStatus(
      {
        'bank_transfer_configured': true,
        'settlement_method': 'bank_transfer',
        'bank_transfer': {
          'account_holder': 'HeyCaby B.V.',
          'iban': 'NL00TEST0000000000',
          'bank_name': 'Test Bank',
          'bic': 'TESTNL2A',
          'reference': 'HC-X933HH',
        },
      },
      amount: '€50.00',
    );

    expect(details, isNotNull);
    expect(details!.reference, 'HC-X933HH');
    expect(details.amount, '€50.00');
  });

  test('does not expose incomplete or disabled bank details', () {
    expect(
      DriverBankTransferDetails.fromBillingStatus(
        const {
          'bank_transfer_configured': false,
          'settlement_method': 'mollie_checkout',
        },
        amount: '€50.00',
      ),
      isNull,
    );

    expect(
      DriverBankTransferDetails.fromBillingStatus(
        const {
          'bank_transfer_configured': true,
          'settlement_method': 'bank_transfer',
          'bank_transfer': {
            'account_holder': 'HeyCaby B.V.',
            'iban': '',
            'bank_name': 'Test Bank',
            'bic': 'TESTNL2A',
            'reference': 'HC-X933HH',
          },
        },
        amount: '€50.00',
      ),
      isNull,
    );
  });
}
