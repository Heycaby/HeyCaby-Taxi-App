import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';

/// Maps [DriverRideLifecycleException] codes to driver-facing copy.
String driverRideLifecycleErrorMessage(Object error) {
  if (error is DriverRideLifecycleException) {
    final message = DriverStrings.rideLifecycleErrorMessage(error.code);
    if (message != DriverStrings.rideActionFailedMessage) {
      return message;
    }
  }
  return DriverStrings.rideActionFailedMessage;
}
