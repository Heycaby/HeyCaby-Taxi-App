import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/taxi_terug_hot_destination.dart';
import '../services/taxi_terug_hot_destinations_service.dart';
import 'booking_provider.dart';

final taxiTerugHotDestinationsServiceProvider =
    Provider<TaxiTerugHotDestinationsService>(
  (ref) => TaxiTerugHotDestinationsService(),
);

/// NL cities with live Taxi Terug driver counts (sorted by supply).
final taxiTerugHotDestinationsProvider =
    FutureProvider.autoDispose<List<TaxiTerugHotDestination>>((ref) async {
  final booking = ref.watch(bookingProvider);
  return ref.read(taxiTerugHotDestinationsServiceProvider).fetchHotDestinations(
        pickup: booking.pickup,
      );
});
