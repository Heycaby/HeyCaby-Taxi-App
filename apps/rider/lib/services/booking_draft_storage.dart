import 'dart:convert';

import 'package:heycaby_models/heycaby_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/booking_provider.dart';

const _prefsKey = 'rider_booking_draft_v1';

/// Local draft of an in-progress booking (save-for-later). Not synced to Supabase.
class BookingDraftStorage {
  BookingDraftStorage._();

  static Future<bool> hasDraft() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    return raw != null && raw.isNotEmpty;
  }

  static Future<void> save(BookingState booking) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(_toJson(booking)));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
  }

  static Future<BookingState?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _fromJson(m);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toJson(BookingState s) {
    return {
      'v': 1,
      'mode': s.mode.name,
      'pickup': s.pickup?.toJson(),
      'destination': s.destination?.toJson(),
      'scheduled_at': s.scheduledAt?.toIso8601String(),
      'pickup_contact_name': s.pickupContactName,
      'payment_methods': s.paymentMethods,
      'vehicle_category': s.vehicleCategory,
      'vehicle_categories': s.vehicleCategories,
      'pet_friendly': s.petFriendly,
      'trip_price_band_min': s.tripPriceBandMinEuro,
      'trip_price_band_max': s.tripPriceBandMaxEuro,
      'selected_driver_id': s.selectedDriverId,
      'estimated_fare_euro': s.estimatedFareEuro,
      'marketplace_bid_euro': s.marketplaceBidEuro,
      'favorites_first': s.favoritesFirst,
      'return_trip_fare_estimates': s.returnTripFareEstimatesEnabled,
    };
  }

  static BookingState _fromJson(Map<String, dynamic> m) {
    BookingMode mode = BookingMode.instant;
    final modeStr = m['mode'] as String?;
    if (modeStr != null) {
      for (final v in BookingMode.values) {
        if (v.name == modeStr) {
          mode = v;
          break;
        }
      }
    }
    AddressResult? pickup;
    final pu = m['pickup'];
    if (pu is Map<String, dynamic>) {
      pickup = AddressResult.fromJson(pu);
    }
    AddressResult? dest;
    final d = m['destination'];
    if (d is Map<String, dynamic>) {
      dest = AddressResult.fromJson(d);
    }
    DateTime? sched;
    final sAt = m['scheduled_at'] as String?;
    if (sAt != null) {
      sched = DateTime.tryParse(sAt);
    }
    final pm = m['payment_methods'];
    final methods = pm is List
        ? pm.map((e) => e.toString()).toList()
        : <String>[];
    final fare = m['estimated_fare_euro'];
    final bid = m['marketplace_bid_euro'];
    final vcats = m['vehicle_categories'];
    final categories = vcats is List
        ? vcats.map((e) => e.toString()).toList()
        : <String>[];
    final bandMin = m['trip_price_band_min'];
    final bandMax = m['trip_price_band_max'];
    return BookingState(
      mode: mode,
      pickup: pickup,
      destination: dest,
      favoritesFirst: (m['favorites_first'] as bool?) ??
          (m['favorites_only'] as bool? ?? false),
      scheduledAt: sched,
      pickupContactName: m['pickup_contact_name'] as String?,
      paymentMethods: methods,
      vehicleCategory: m['vehicle_category'] as String?,
      vehicleCategories: categories,
      petFriendly: m['pet_friendly'] as bool? ?? false,
      selectedDriverId: m['selected_driver_id'] as String?,
      estimatedFareEuro: fare is num ? fare.toDouble() : null,
      tripPriceBandMinEuro: bandMin is num ? bandMin.toDouble() : null,
      tripPriceBandMaxEuro: bandMax is num ? bandMax.toDouble() : null,
      marketplaceBidEuro: bid is int
          ? bid
          : bid is num
              ? bid.round()
              : null,
      returnTripFareEstimatesEnabled:
          m['return_trip_fare_estimates'] as bool? ?? false,
    );
  }
}
