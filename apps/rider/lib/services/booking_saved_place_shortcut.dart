import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../providers/booking_provider.dart';
import '../providers/saved_addresses_provider.dart';
import 'booking_flow_navigation.dart';
import 'booking_pickup_from_location.dart';

/// How [bookInstantRideToDestination] should return after applying the place.
enum SavedPlaceBookingNavigation {
  /// Saved places screen — open search or pop back when opened from search.
  fullScreen,

  /// Saved places bottom sheet — close sheet; search underneath stays visible.
  closeSheet,
}

AddressResult addressResultFromSaved(SavedAddress saved) {
  return AddressResult(
    displayName: saved.label,
    fullAddress: saved.fullAddress,
    lat: saved.latitude,
    lng: saved.longitude,
  );
}

/// Sets destination and opens search. Sync work runs immediately on tap.
Future<bool> bookInstantRideToDestination(
  BuildContext context,
  WidgetRef ref,
  AddressResult destination, {
  SavedPlaceBookingNavigation navigation = SavedPlaceBookingNavigation.fullScreen,
}) async {
  if (!context.mounted) return false;

  try {
    ref.read(bookingProvider.notifier)
      ..setInstant()
      ..setDestination(destination);

    if (!context.mounted) return false;

    final fromSearch =
        GoRouterState.of(context).uri.queryParameters['from'] == 'search';

    switch (navigation) {
      case SavedPlaceBookingNavigation.closeSheet:
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;
      case SavedPlaceBookingNavigation.fullScreen:
        if (fromSearch && context.canPop()) {
          context.pop();
        } else {
          context.push('/search');
        }
        break;
    }

    unawaited(_resolvePickupAndProfile(ref));
    return true;
  } catch (e, st) {
    debugPrint('bookInstantRideToDestination failed: $e\n$st');
    return false;
  }
}

Future<void> _resolvePickupAndProfile(WidgetRef ref) async {
  if (ref.read(bookingProvider).pickup == null) {
    await fillPickupFromCurrentLocation(ref);
  }
  await BookingFlowNavigation.prefillBookingFromIdentity(ref);
}
