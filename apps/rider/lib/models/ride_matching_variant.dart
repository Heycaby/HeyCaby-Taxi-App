import '../providers/booking_provider.dart';

/// Which matching UX to show — TAXI TERUG reuses the marketplace-style route.
enum RideMatchingVariant { instant, marketplace, scheduled, terug }

extension RideMatchingVariantRoute on RideMatchingVariant {
  String get routePath {
    switch (this) {
      case RideMatchingVariant.instant:
        return '/searching';
      case RideMatchingVariant.marketplace:
      case RideMatchingVariant.terug:
        return '/marketplace-matching';
      case RideMatchingVariant.scheduled:
        return '/scheduled-matching';
    }
  }
}

RideMatchingVariant rideMatchingVariantForBookingModeString(String? mode) {
  switch (mode) {
    case 'marketplace':
      return RideMatchingVariant.marketplace;
    case 'terug':
      return RideMatchingVariant.terug;
    case 'scheduled':
      return RideMatchingVariant.scheduled;
    default:
      return RideMatchingVariant.instant;
  }
}

RideMatchingVariant rideMatchingVariantForBookingMode(BookingMode mode) {
  switch (mode) {
    case BookingMode.marketplace:
      return RideMatchingVariant.marketplace;
    case BookingMode.terug:
      return RideMatchingVariant.terug;
    case BookingMode.scheduled:
      return RideMatchingVariant.scheduled;
    case BookingMode.instant:
      return RideMatchingVariant.instant;
  }
}

/// Value stored in `ride_requests.booking_mode` / used by [rideMatchingVariantForBookingModeString].
String bookingModeStorageString(BookingMode mode) {
  switch (mode) {
    case BookingMode.instant:
      return 'instant';
    case BookingMode.marketplace:
      return 'marketplace';
    case BookingMode.scheduled:
      return 'scheduled';
    case BookingMode.terug:
      return 'terug';
  }
}
