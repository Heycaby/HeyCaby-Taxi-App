import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/utils/driver_ride_lifecycle_error_message.dart';

void main() {
  test('prepayment gate tells the Driver to wait for confirmation', () {
    final message = driverRideLifecycleErrorMessage(
      const DriverRideLifecycleException('ride_prepayment_required'),
    );

    expect(message.toLowerCase(), contains('betaling'));
    expect(message.toLowerCase(), contains('bevestigd'));
  });

  test('maps too_far_from_pickup to proximity copy', () {
    expect(
      driverRideLifecycleErrorMessage(
        const DriverRideLifecycleException('too_far_from_pickup'),
      ),
      contains('500 m'),
    );
  });

  test('unknown lifecycle errors name the backend reason', () {
    final message = driverRideLifecycleErrorMessage(
      const DriverRideLifecycleException('some_new_backend_code'),
    );
    expect(message, isNot(DriverStrings.rideActionFailedMessage));
    expect(message.toLowerCase(), contains('some new backend code'));
  });

  test('maps driver_location_unavailable to GPS copy', () {
    expect(
      driverRideLifecycleErrorMessage(
        const DriverRideLifecycleException('driver_location_unavailable'),
      ),
      contains('GPS'),
    );
  });

  test('extracts driver_business_account_not_found from postgres wrapper', () {
    expect(
      driverRideLifecycleErrorMessage(
        const DriverRideLifecycleException(
          'rpc_error',
          message: 'driver_business_account_not_found',
        ),
      ),
      contains('account'),
    );
  });

  test('maps network failures without generic connection copy', () {
    final message = driverRideLifecycleErrorMessage(
      const DriverRideLifecycleException('network_unreachable'),
    );
    expect(message, isNot(DriverStrings.rideActionFailedMessage));
    expect(message.toLowerCase(), contains('internet'));
  });
}
