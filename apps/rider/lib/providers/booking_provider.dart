import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

import '../models/rider_vehicle_category.dart';

enum BookingMode { instant, marketplace, scheduled }

class BookingState {
  final BookingMode mode;
  final AddressResult? pickup;
  final AddressResult? destination;
  final bool favoritesFirst;
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

  const BookingState({
    this.mode = BookingMode.instant,
    this.pickup,
    this.destination,
    this.favoritesFirst = false,
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
  });

  BookingState copyWith({
    BookingMode? mode,
    AddressResult? pickup,
    AddressResult? destination,
    bool? favoritesFirst,
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
  }) =>
      BookingState(
        mode: mode ?? this.mode,
        pickup: pickup ?? this.pickup,
        destination: destination ?? this.destination,
        favoritesFirst: favoritesFirst ?? this.favoritesFirst,
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
      );

  /// Used for `booking_mode` in Supabase and matching-route selection.
  /// Marketplace wins; any pickup time implies scheduled; otherwise [mode].
  BookingMode get effectiveRideMode {
    if (mode == BookingMode.marketplace) return BookingMode.marketplace;
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
  void setMarketplace() => state = state.copyWith(mode: BookingMode.marketplace);

  void setMarketplaceBidEuro(int euros) =>
      state = state.copyWith(marketplaceBidEuro: euros);
  void setScheduled() => state = state.copyWith(
        mode: BookingMode.scheduled,
        marketplaceBidEuro: null,
      );

  void setPickup(AddressResult pickup) => state = state.copyWith(pickup: pickup);
  void setDestination(AddressResult destination) =>
      state = state.copyWith(destination: destination);

  void clearPickup() => state = state.copyWith(pickup: null);
  void clearDestination() => state = state.copyWith(destination: null);

  void setFavoritesFirst(bool value) =>
      state = state.copyWith(favoritesFirst: value);

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

  void applyVehicleSelection(List<String> categories, {required bool petFriendly}) {
    if (categories.isEmpty) return;
    state = state.copyWith(
      vehicleCategories: List<String>.from(categories),
      vehicleCategory: categories.first,
      petFriendly: petFriendly,
    );
  }

  void setVehicleCategory(String category, {bool petFriendly = false}) =>
      applyVehicleSelection([category], petFriendly: petFriendly);

  void setTripPriceBand({double? minEuro, double? maxEuro}) {
    state = state.copyWith(
      tripPriceBandMinEuro: minEuro,
      tripPriceBandMaxEuro: maxEuro,
    );
  }

  /// Select a specific driver and store their estimated fare.
  void setSelectedDriver(String driverId, double fare) => state = state.copyWith(
        selectedDriverId: driverId,
        estimatedFareEuro: fare,
      );

  /// Clear specific-driver selection — ride will be posted to all nearby drivers.
  void clearSelectedDriver() => state = state.copyWith(
        selectedDriverId: null,
        estimatedFareEuro: null,
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
