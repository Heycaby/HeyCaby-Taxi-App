import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/utils/accept_ride_error_message.dart';

void main() {
  test('acceptRideErrorMessageFor prefers reason over generic expired copy', () {
    const e = DriverAcceptRideException(
      'no_valid_invite',
      reason: 'gps_stale',
      message: 'Your GPS location is stale.',
    );
    expect(
      acceptRideErrorMessageFor(e),
      DriverStrings.acceptRideErrorMessage('gps_stale'),
    );
  });

  test('acceptRideErrorMessageFor uses server message when code unknown', () {
    const e = DriverAcceptRideException(
      'rpc_failed',
      message: 'Database lock timeout.',
    );
    expect(
      acceptRideErrorMessageFor(e),
      contains('Database lock timeout'),
    );
  });

  test('default accept failure does not mention expired', () {
    expect(
      DriverStrings.acceptRideFailedMessage.toLowerCase(),
      isNot(contains('expired')),
    );
    expect(
      DriverStrings.acceptRideFailedMessage.toLowerCase(),
      isNot(contains('verlopen')),
    );
  });
}
