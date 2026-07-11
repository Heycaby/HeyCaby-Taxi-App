import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/taxi_terug_candidate.dart';
import '../services/taxi_terug_supply_service.dart';
import 'booking_provider.dart';

final taxiTerugSupplyServiceProvider = Provider<TaxiTerugSupplyService>(
  (ref) => TaxiTerugSupplyService(),
);

/// Live Taxi Terug candidates for the current pickup → destination route.
final taxiTerugCandidatesProvider =
    FutureProvider.autoDispose<TaxiTerugCandidatesSnapshot>((ref) async {
  final booking = ref.watch(bookingProvider);
  if (booking.mode != BookingMode.terug) {
    return const TaxiTerugCandidatesSnapshot(enabled: false, candidates: []);
  }
  final pickup = booking.pickup;
  final destination = booking.destination;
  if (pickup == null || destination == null) {
    return const TaxiTerugCandidatesSnapshot(enabled: true, candidates: []);
  }
  return ref.read(taxiTerugSupplyServiceProvider).fetchCandidates(
        pickup: pickup,
        destination: destination,
        maxWaitMinutes: booking.taxiTerugMaxWaitMinutes,
      );
});
