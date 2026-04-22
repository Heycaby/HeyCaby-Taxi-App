import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/booking_provider.dart';

/// Pass as [GoRouter.push] `extra` when opening vehicle/payment from trip summary
/// so Continue returns to [TripSummaryScreen] instead of stacking another summary.
const String kBookingReturnToSummaryExtra = 'booking_return_summary';

/// Routes and profile merge for the book-a-ride stack (skip steps when data exists).
///
/// Use [routeAfterAddressesComplete] after both addresses are set — from search,
/// marketplace “continue”, or home saved-address / recent-destination shortcuts
/// (always call [prefillBookingFromIdentity] first for returning-user skips).
class BookingFlowNavigation {
  BookingFlowNavigation._();

  static Future<void> prefillBookingFromIdentity(WidgetRef ref) async {
    final identity = await ref.read(riderIdentityProvider.future);
    ref.read(bookingProvider.notifier).mergeFromRiderIdentity(identity);
  }

  static String routeAfterAddressesComplete(BookingState booking) {
    final vc = booking.vehicleCategory?.trim() ?? '';
    if (vc.isEmpty) return '/vehicle-category';
    if (booking.paymentMethods.isEmpty) return '/payment';
    return '/summary';
  }

  static String routeAfterVehicleComplete(BookingState booking) {
    if (booking.paymentMethods.isEmpty) return '/payment';
    return '/summary';
  }
}
