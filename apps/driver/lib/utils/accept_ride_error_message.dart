import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';

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

/// Close opportunity UI when the ride is no longer available to this driver.
bool shouldDismissAfterAcceptError(DriverAcceptRideException e) {
  final normalized = (e.reason ?? e.code).split(':').first.trim();
  return normalized == 'race_lost' ||
      normalized == 'ride_not_found' ||
      normalized == 'ride_cancelled' ||
      normalized == 'database_conflict' ||
      normalized == 'ride_not_pending' ||
      normalized == 'no_valid_invite' ||
      normalized == 'invite_missing' ||
      normalized == 'invite_expired' ||
      normalized == 'invite_not_pending' ||
      normalized == 'ride_expired' ||
      normalized == 'scheduled_departed' ||
      normalized == 'driver_not_eligible' ||
      normalized == 'driver_not_ready' ||
      normalized == 'driver_not_prepay_ready' ||
      normalized == 'driver_offline' ||
      normalized == 'driver_suspended' ||
      normalized == 'queued_taxi_terug' ||
      normalized == 'vehicle_mismatch' ||
      normalized == 'electric_vehicle_required' ||
      normalized == 'wheelchair_vehicle_required' ||
      normalized == 'pets_not_supported';
}

void invalidateScheduledRideProviders(WidgetRef ref) {
  ref.invalidate(scheduledRidesCountProvider);
  ref.invalidate(scheduledRidesProvider);
  ref.invalidate(scheduledRidesByTabProvider);
}
