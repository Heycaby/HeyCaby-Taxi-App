import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_category_estimate.dart';
import '../services/trip_category_pricing_service.dart';
import 'booking_provider.dart';

/// Trip-level category prices from Supabase (pickup + destination required).
final tripCategoryEstimatesProvider =
    FutureProvider.autoDispose<List<TripCategoryEstimate>>((ref) async {
  final booking = ref.watch(bookingProvider);
  final pu = booking.pickup;
  final de = booking.destination;
  if (pu == null || de == null) return [];

  return TripCategoryPricingService.fetchEstimates(
    pickupLng: pu.lng,
    pickupLat: pu.lat,
    destLng: de.lng,
    destLat: de.lat,
  );
});
