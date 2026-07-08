import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/utils/driver_ride_lifecycle_error_message.dart';

void main() {
  test('maps too_far_from_pickup to proximity copy', () {
    expect(
      driverRideLifecycleErrorMessage(
        const DriverRideLifecycleException('too_far_from_pickup'),
      ),
      contains('500 m'),
    );
  });

  test('falls back for unknown lifecycle errors', () {
    expect(
      driverRideLifecycleErrorMessage(
        const DriverRideLifecycleException('unknown'),
      ),
      DriverStrings.rideActionFailedMessage,
    );
  });
}
