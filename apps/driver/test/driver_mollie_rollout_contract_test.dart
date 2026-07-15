import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/models/driver_runtime_models.dart';

void main() {
  test('Mollie Connect is disabled when the flag is absent', () {
    expect(DriverRemoteConfig.fromJson(const {}).mollieConnectEnabled, isFalse);
  });

  test('Mollie Connect reads the canonical runtime feature flag', () {
    final config = DriverRemoteConfig.fromJson({
      'feature_flags': {'ride_prepaid_driver_connect_enabled': true},
    });

    expect(config.mollieConnectEnabled, isTrue);
  });

  test('prepaid settlement requires global and marketplace capability flags', () {
    final withoutCapability = DriverRemoteConfig.fromJson({
      'feature_flags': {'ride_prepaid_payments_enabled': true},
    });
    final enabled = DriverRemoteConfig.fromJson({
      'feature_flags': {
        'ride_prepaid_payments_enabled': true,
        'mollie_marketplace_routing_enabled': true,
      },
    });

    expect(withoutCapability.prepaidPaymentsEnabled, isFalse);
    expect(enabled.prepaidPaymentsEnabled, isTrue);
  });
}
