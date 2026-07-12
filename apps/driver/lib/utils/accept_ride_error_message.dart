import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';

/// Maps [DriverAcceptRideException] to user-facing copy without collapsing to "expired".
String acceptRideErrorMessageFor(DriverAcceptRideException e) {
  final serverMessage = e.message?.trim();
  final reason = e.reason?.split(':').first.trim();
  if (reason != null && reason.isNotEmpty) {
    final byReason = DriverStrings.acceptRideErrorMessage(reason);
    if (byReason != DriverStrings.acceptRideFailedMessage &&
        byReason != DriverStrings.rideActionFailedMessage) {
      return byReason;
    }
  }
  if (serverMessage != null && serverMessage.isNotEmpty) {
    return DriverStrings.rideLifecycleErrorExplicit(
      e.code,
      detail: serverMessage,
    );
  }
  final byCode = DriverStrings.acceptRideErrorMessage(e.code);
  if (byCode != DriverStrings.acceptRideFailedMessage &&
      byCode != DriverStrings.rideActionFailedMessage) {
    return byCode;
  }
  return DriverStrings.rideLifecycleErrorExplicit(e.code);
}
