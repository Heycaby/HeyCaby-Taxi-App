import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';

/// Maps [DriverAcceptRideException] to user-facing copy without collapsing to "expired".
String acceptRideErrorMessageFor(DriverAcceptRideException e) {
  final serverMessage = e.message?.trim();
  final reason = e.reason?.split(':').first.trim();
  if (reason != null && reason.isNotEmpty) {
    final byReason = DriverStrings.acceptRideErrorMessage(reason);
    if (byReason != DriverStrings.acceptRideFailedMessage) return byReason;
  }
  final byCode = DriverStrings.acceptRideErrorMessage(e.code);
  if (byCode != DriverStrings.acceptRideFailedMessage &&
      byCode != DriverStrings.rideActionFailedMessage) {
    return byCode;
  }
  if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;
  if (byCode == DriverStrings.rideActionFailedMessage) return byCode;
  return DriverStrings.acceptRideFailedMessage;
}
