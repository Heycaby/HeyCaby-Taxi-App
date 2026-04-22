import 'package:heycaby_rider/l10n/app_localizations.dart';

/// Short UI label for `ride_requests.booking_mode` (instant | marketplace | scheduled).
String rideMatchingTypeShortLabel(AppLocalizations l10n, String bookingMode) {
  switch (bookingMode) {
    case 'marketplace':
      return l10n.rideMatchingTypeLabelMarketplace;
    case 'scheduled':
      return l10n.rideMatchingTypeLabelScheduled;
    default:
      return l10n.rideMatchingTypeLabelInstant;
  }
}
