import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/utils/accept_ride_error_message.dart';

void main() {
  test('acceptRideErrorMessageFor prefers reason over generic expired copy',
      () {
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

  test('shouldDismissAfterAcceptError closes sheet for race_lost', () {
    const e =
        DriverAcceptRideException('race_lost', reason: 'database_conflict');
    expect(shouldDismissAfterAcceptError(e), isTrue);
  });

  test('shouldDismissAfterAcceptError keeps sheet for billing_locked', () {
    const e =
        DriverAcceptRideException('billing_locked', reason: 'billing_locked');
    expect(shouldDismissAfterAcceptError(e), isFalse);
  });

  test('runtime eligibility loss closes the stale opportunity', () {
    const e = DriverAcceptRideException(
      'driver_not_eligible',
      reason: 'vehicle_mismatch',
    );
    expect(shouldDismissAfterAcceptError(e), isTrue);
    expect(
      acceptRideErrorMessageFor(e),
      DriverStrings.acceptRideErrorMessage('vehicle_mismatch'),
    );
  });

  test('server-expired ride closes with unavailable copy', () {
    const e = DriverAcceptRideException(
      'ride_expired',
      reason: 'ride_expired',
    );
    expect(shouldDismissAfterAcceptError(e), isTrue);
    expect(
      acceptRideErrorMessageFor(e),
      DriverStrings.acceptRideErrorMessage('ride_expired'),
    );
  });

  test('scheduled ride-fit failures close the stale catalog entry', () {
    for (final reason in <String>[
      'scheduled_departed',
      'electric_vehicle_required',
      'wheelchair_vehicle_required',
    ]) {
      final e = DriverAcceptRideException(
        'driver_not_eligible',
        reason: reason,
      );
      expect(shouldDismissAfterAcceptError(e), isTrue, reason: reason);
      expect(
        acceptRideErrorMessageFor(e),
        DriverStrings.acceptRideErrorMessage(reason),
        reason: reason,
      );
    }
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

  test('prepayment readiness loss closes the stale opportunity', () {
    const e = DriverAcceptRideException(
      'driver_not_eligible',
      reason: 'driver_not_prepay_ready',
    );
    expect(shouldDismissAfterAcceptError(e), isTrue);
    expect(
      acceptRideErrorMessageFor(e),
      DriverStrings.acceptRideErrorMessage('driver_not_prepay_ready'),
    );
  });
}
