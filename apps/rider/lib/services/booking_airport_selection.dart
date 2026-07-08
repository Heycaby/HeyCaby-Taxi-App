import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/benelux_airports.dart';
import '../providers/booking_provider.dart';
import '../providers/local_recent_addresses_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../screens/location_required_screen.dart';
import 'booking_flow_navigation.dart';
import 'booking_pickup_from_location.dart';

/// Sets airport destination and continues the standard instant booking flow.
Future<void> startBookingWithAirportDestination({
  required WidgetRef ref,
  required BuildContext context,
  required BeneluxAirport airport,
}) async {
  ref.read(bookingProvider.notifier).setInstant();
  final dest = airport.toAddressResult();
  ref.read(bookingProvider.notifier).setDestination(dest);
  await ref.read(localRecentAddressesProvider.notifier).record(dest);
  unawaited(
    ref.read(recentDestinationsProvider.notifier).recordDestination(
          fullAddress: dest.fullAddress,
          lat: dest.lat,
          lng: dest.lng,
        ),
  );

  if (!context.mounted) return;
  final locationOk = await ensureLocationForBooking(
    context: context,
    ref: ref,
  );
  if (locationOk) {
    await fillPickupFromCurrentLocation(ref);
  }

  await BookingFlowNavigation.prefillBookingFromIdentity(ref);
  if (!context.mounted) return;
  final booking = ref.read(bookingProvider);
  if (booking.pickup == null || booking.destination == null) {
    context.push('/search');
  } else {
    context.push(BookingFlowNavigation.routeAfterAddressesComplete(booking));
  }
}

/// One-tap airports surfaced on home (Phase 1 discoverability).
const List<String> kHomePopularAirportIatas = ['AMS', 'RTM', 'EIN', 'BRU'];

List<BeneluxAirport> get homePopularAirports {
  final byIata = {for (final a in kBeneluxAirports) a.iata: a};
  return kHomePopularAirportIatas
      .map((iata) => byIata[iata])
      .whereType<BeneluxAirport>()
      .toList();
}
