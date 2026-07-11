import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/rider_vehicle_category.dart';

enum BookingMode { instant, marketplace, scheduled, terug }

/// Who receives a marketplace trip request (maps to ride_requests flags).
enum MarketplaceDriverAudience {
  everyone,
  myDriversFirst,
  myDriversOnly,
}

class BookingState {
  final BookingMode mode;
  final AddressResult? pickup;
  final AddressResult? destination;
  final bool favoritesFirst;
  final bool favoritesOnly;
  final MarketplaceDriverAudience marketplaceDriverAudience;
  final DateTime? scheduledAt;
  final String? pickupContactName;
  final String? paymentMethod;
  final List<String> paymentMethods;
  final String? vehicleCategory;

  /// When non-empty, matching uses all listed keys (see ride_requests.vehicle_categories).
  final List<String> vehicleCategories;
  final bool petFriendly;

  /// ID of the specific driver the rider selected (null = post to all).
  final String? selectedDriverId;

  /// Estimated fare for the selected driver's pricing (null when post-to-all).
  final double? estimatedFareEuro;

  /// Smart-bundle trip estimate (multi-category); shown on summary when set.
  final double? tripPriceBandMinEuro;
  final double? tripPriceBandMaxEuro;

  /// Marketplace rider offer in whole euros (maps to `ride_requests.marketplace_offered_fare`).
  final int? marketplaceBidEuro;

  /// When true, nearby driver supply uses each driver's [active_return_discount_pct] on the
  /// heuristic tariff estimate (return-trip offers only). When false, estimates use full tariff.
  final bool returnTripFareEstimatesEnabled;

  /// Mapbox route distance/duration from trip summary (preferred over haversine at booking).
  final double? routeDistanceKm;
  final int? routeDurationMin;

  /// Taxi Terug: max minutes rider will wait for pickup (filters in-transit drivers).
  final int taxiTerugMaxWaitMinutes;

  /// Best single € quote for persistence and summary UI.
  double? get quotedFareEuro {
    if (marketplaceBidEuro != null && marketplaceBidEuro! > 0) {
      return marketplaceBidEuro!.toDouble();
    }
    if (estimatedFareEuro != null && estimatedFareEuro! > 0) {
      return estimatedFareEuro;
    }
    if (tripPriceBandMinEuro != null &&
        tripPriceBandMaxEuro != null &&
        tripPriceBandMinEuro! > 0 &&
        tripPriceBandMaxEuro! > 0) {
      return (tripPriceBandMinEuro! + tripPriceBandMaxEuro!) / 2;
    }
    if (tripPriceBandMaxEuro != null && tripPriceBandMaxEuro! > 0) {
      return tripPriceBandMaxEuro;
    }
    if (tripPriceBandMinEuro != null && tripPriceBandMinEuro! > 0) {
      return tripPriceBandMinEuro;
    }
    return null;
  }

  const BookingState({
    this.mode = BookingMode.instant,
    this.pickup,
    this.destination,
    this.favoritesFirst = false,
    this.favoritesOnly = false,
    this.marketplaceDriverAudience = MarketplaceDriverAudience.everyone,
    this.scheduledAt,
    this.pickupContactName,
    this.paymentMethod,
    this.paymentMethods = const [],
    this.vehicleCategory,
    this.vehicleCategories = const [],
    this.petFriendly = false,
    this.selectedDriverId,
    this.estimatedFareEuro,
    this.tripPriceBandMinEuro,
    this.tripPriceBandMaxEuro,
    this.marketplaceBidEuro,
    this.returnTripFareEstimatesEnabled = false,
    this.routeDistanceKm,
    this.routeDurationMin,
    this.taxiTerugMaxWaitMinutes = 60,
  });

  BookingState copyWith({
    BookingMode? mode,
    AddressResult? pickup,
    AddressResult? destination,
    bool? favoritesFirst,
    bool? favoritesOnly,
    MarketplaceDriverAudience? marketplaceDriverAudience,
    DateTime? scheduledAt,
    String? pickupContactName,
    Object? paymentMethod = _sentinel,
    List<String>? paymentMethods,
    String? vehicleCategory,
    List<String>? vehicleCategories,
    bool? petFriendly,
    Object? selectedDriverId = _sentinel,
    Object? estimatedFareEuro = _sentinel,
    Object? tripPriceBandMinEuro = _sentinel,
    Object? tripPriceBandMaxEuro = _sentinel,
    Object? marketplaceBidEuro = _sentinel,
    Object? returnTripFareEstimatesEnabled = _sentinel,
    Object? routeDistanceKm = _sentinel,
    Object? routeDurationMin = _sentinel,
    int? taxiTerugMaxWaitMinutes,
  }) =>
      BookingState(
        mode: mode ?? this.mode,
        pickup: pickup ?? this.pickup,
        destination: destination ?? this.destination,
        favoritesFirst: favoritesFirst ?? this.favoritesFirst,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        marketplaceDriverAudience:
            marketplaceDriverAudience ?? this.marketplaceDriverAudience,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        pickupContactName: pickupContactName ?? this.pickupContactName,
        paymentMethod: paymentMethod == _sentinel
            ? this.paymentMethod
            : paymentMethod as String?,
        paymentMethods: paymentMethods ?? this.paymentMethods,
        vehicleCategory: vehicleCategory ?? this.vehicleCategory,
        vehicleCategories: vehicleCategories ?? this.vehicleCategories,
        petFriendly: petFriendly ?? this.petFriendly,
        selectedDriverId: selectedDriverId == _sentinel
            ? this.selectedDriverId
            : selectedDriverId as String?,
        estimatedFareEuro: estimatedFareEuro == _sentinel
            ? this.estimatedFareEuro
            : estimatedFareEuro as double?,
        tripPriceBandMinEuro: tripPriceBandMinEuro == _sentinel
            ? this.tripPriceBandMinEuro
            : tripPriceBandMinEuro as double?,
        tripPriceBandMaxEuro: tripPriceBandMaxEuro == _sentinel
            ? this.tripPriceBandMaxEuro
            : tripPriceBandMaxEuro as double?,
        marketplaceBidEuro: marketplaceBidEuro == _sentinel
            ? this.marketplaceBidEuro
            : marketplaceBidEuro as int?,
        returnTripFareEstimatesEnabled:
            returnTripFareEstimatesEnabled == _sentinel
                ? this.returnTripFareEstimatesEnabled
                : returnTripFareEstimatesEnabled as bool,
        routeDistanceKm: routeDistanceKm == _sentinel
            ? this.routeDistanceKm
            : routeDistanceKm as double?,
        routeDurationMin: routeDurationMin == _sentinel
            ? this.routeDurationMin
            : routeDurationMin as int?,
        taxiTerugMaxWaitMinutes:
            taxiTerugMaxWaitMinutes ?? this.taxiTerugMaxWaitMinutes,
      );

  /// Used for `booking_mode` in Supabase and matching-route selection.
  /// Named-price modes win; any pickup time implies scheduled; otherwise [mode].
  BookingMode get effectiveRideMode {
    if (mode == BookingMode.marketplace) return BookingMode.marketplace;
    if (mode == BookingMode.terug) return BookingMode.terug;
    if (scheduledAt != null) return BookingMode.scheduled;
    return mode;
  }
}

// Sentinel for nullable copyWith fields
const Object _sentinel = Object();

class BookingNotifier extends Notifier<BookingState> {
  @override
  BookingState build() => const BookingState();

  void setInstant() => state = state.copyWith(
        mode: BookingMode.instant,
        marketplaceBidEuro: null,
      );
  void setMarketplace() =>
      state = state.copyWith(mode: BookingMode.marketplace);
  void setTaxiTerug() => state = state.copyWith(mode: BookingMode.terug);

  void setTaxiTerugMaxWaitMinutes(int minutes) => state = state.copyWith(
        taxiTerugMaxWaitMinutes: minutes.clamp(15, 120),
      );

  void setMarketplaceBidEuro(int euros) =>
      state = state.copyWith(marketplaceBidEuro: euros);
  void setScheduled() => state = state.copyWith(
        mode: BookingMode.scheduled,
        marketplaceBidEuro: null,
      );

  void setPickup(AddressResult pickup) => state = state.copyWith(
        pickup: pickup,
        routeDistanceKm: null,
        routeDurationMin: null,
      );
  void setDestination(AddressResult destination) => state = state.copyWith(
        destination: destination,
        routeDistanceKm: null,
        routeDurationMin: null,
      );

  void clearPickup() => state = state.copyWith(
        pickup: null,
        routeDistanceKm: null,
        routeDurationMin: null,
      );
  void clearDestination() => state = state.copyWith(
        destination: null,
        routeDistanceKm: null,
        routeDurationMin: null,
      );

  void setFavoritesFirst(bool value) =>
      state = state.copyWith(favoritesFirst: value);

  void setMarketplaceDriverAudience(MarketplaceDriverAudience audience) {
    state = state.copyWith(
      marketplaceDriverAudience: audience,
      favoritesFirst: audience == MarketplaceDriverAudience.myDriversFirst ||
          audience == MarketplaceDriverAudience.myDriversOnly,
      favoritesOnly: audience == MarketplaceDriverAudience.myDriversOnly,
    );
  }

  void setPetFriendly(bool value) => state = state.copyWith(petFriendly: value);

  void setScheduledAt(DateTime dt) => state = state.copyWith(
        scheduledAt: dt,
        mode: BookingMode.scheduled,
      );

  void setPickupContactName(String name) =>
      state = state.copyWith(pickupContactName: name);

  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);

  void setPaymentMethods(List<String> methods) => state = state.copyWith(
        paymentMethods: methods,
        paymentMethod: null,
      );

  void applyVehicleSelection(List<String> categories,
      {required bool petFriendly}) {
    if (categories.isEmpty) return;
    final trimmed = categories.take(3).toList();
    state = state.copyWith(
      vehicleCategories: List<String>.from(trimmed),
      vehicleCategory: trimmed.first,
      petFriendly: petFriendly,
    );
  }

  void setVehicleCategory(String category, {bool petFriendly = false}) =>
      applyVehicleSelection([category], petFriendly: petFriendly);

  void setTripPriceBand({double? minEuro, double? maxEuro}) {
    double? midpoint;
    if (minEuro != null && maxEuro != null && minEuro > 0 && maxEuro > 0) {
      midpoint = (minEuro + maxEuro) / 2;
    } else if (maxEuro != null && maxEuro > 0) {
      midpoint = maxEuro;
    } else if (minEuro != null && minEuro > 0) {
      midpoint = minEuro;
    }
    state = state.copyWith(
      tripPriceBandMinEuro: minEuro,
      tripPriceBandMaxEuro: maxEuro,
      estimatedFareEuro: midpoint ?? state.estimatedFareEuro,
    );
  }

  /// Select a specific driver without forcing a €0 fare into the booking.
  void setPreferredDriver(String driverId) => state = state.copyWith(
        selectedDriverId: driverId,
      );

  /// Select a specific driver and store their estimated fare.
  void setSelectedDriver(String driverId, double fare) =>
      state = state.copyWith(
        selectedDriverId: driverId,
        estimatedFareEuro: fare > 0 ? fare : null,
      );

  /// Clear specific-driver selection — ride will be posted to all nearby drivers.
  void clearSelectedDriver() => state = state.copyWith(
        selectedDriverId: null,
        estimatedFareEuro: null,
      );

  /// Rider-only: use return-trip discount on heuristic supply fares (see [BookingState.returnTripFareEstimatesEnabled]).
  void setReturnTripFareEstimatesEnabled(bool enabled) =>
      state = state.copyWith(returnTripFareEstimatesEnabled: enabled);

  void setRouteMetrics({
    required double distanceKm,
    required int durationMin,
  }) =>
      state = state.copyWith(
        routeDistanceKm: distanceKm,
        routeDurationMin: durationMin,
      );

  void reset() => state = const BookingState();

  /// Restore a locally saved draft (save-for-later).
  void restoreFromDraft(BookingState draft) => state = draft;

  /// Fills empty booking fields from rider profile (returning-user fast path).
  void mergeFromRiderIdentity(RiderIdentityState identity) {
    if (!identity.isLoaded) return;
    var next = state;

    final name = next.pickupContactName?.trim() ?? '';
    if (name.isEmpty) {
      final bn = identity.bookingName?.trim() ?? '';
      if (bn.isNotEmpty) {
        next = next.copyWith(pickupContactName: bn);
      }
    }

    if (next.paymentMethods.isEmpty &&
        identity.preferredPaymentMethods.isNotEmpty) {
      next = next.copyWith(
        paymentMethods: List<String>.from(identity.preferredPaymentMethods),
      );
    }

    final vc = next.vehicleCategory?.trim() ?? '';
    if (vc.isEmpty) {
      final pref = identity.preferredVehicleCategory?.trim();
      if (pref != null && pref.isNotEmpty) {
        final parsed = RiderVehicleCategory.tryParse(pref);
        if (parsed != null) {
          final k = parsed.storageKey;
          next = next.copyWith(
            vehicleCategory: k,
            vehicleCategories: [k],
            petFriendly: identity.preferredPetFriendly ?? next.petFriendly,
          );
        }
      }
    }

    state = next;
  }
}

final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(
  BookingNotifier.new,
);
