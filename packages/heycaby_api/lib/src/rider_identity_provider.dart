import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage.dart';
import 'supabase_client.dart';

class RiderIdentityState {
  final String? riderToken;
  final String? identityId;
  final String? email;
  final String? bookingName;
  /// Cached default payment methods (`cash`, `pin`, `tikkie`) for the booking flow.
  final List<String> preferredPaymentMethods;
  final String? preferredVehicleCategory;
  final bool? preferredPetFriendly;
  final bool isLoaded;

  const RiderIdentityState({
    this.riderToken,
    this.identityId,
    this.email,
    this.bookingName,
    this.preferredPaymentMethods = const [],
    this.preferredVehicleCategory,
    this.preferredPetFriendly,
    this.isLoaded = false,
  });

  bool get hasSession => riderToken != null && riderToken!.isNotEmpty;

  RiderIdentityState copyWith({
    String? riderToken,
    String? identityId,
    String? email,
    String? bookingName,
    List<String>? preferredPaymentMethods,
    String? preferredVehicleCategory,
    bool? preferredPetFriendly,
    bool? isLoaded,
  }) =>
      RiderIdentityState(
        riderToken: riderToken ?? this.riderToken,
        identityId: identityId ?? this.identityId,
        email: email ?? this.email,
        bookingName: bookingName ?? this.bookingName,
        preferredPaymentMethods:
            preferredPaymentMethods ?? this.preferredPaymentMethods,
        preferredVehicleCategory:
            preferredVehicleCategory ?? this.preferredVehicleCategory,
        preferredPetFriendly:
            preferredPetFriendly ?? this.preferredPetFriendly,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

class RiderIdentityNotifier extends AsyncNotifier<RiderIdentityState> {
  @override
  Future<RiderIdentityState> build() async {
    final stored = await SecureStorage.getRiderIdentity();
    var local = _stateFromStored(stored);
    if (local.identityId != null && local.identityId!.isNotEmpty) {
      local = await _mergeServerProfile(local) ?? local;
    }
    return local;
  }

  RiderIdentityState _stateFromStored(Map<String, String?> stored) {
    List<String> pay = const [];
    final payRaw = stored['rider_preferred_payment_json'];
    if (payRaw != null && payRaw.isNotEmpty) {
      try {
        final d = jsonDecode(payRaw);
        if (d is List) {
          pay = d.map((e) => '$e').where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    final petRaw = stored['rider_preferred_pet_friendly'];
    bool? pet;
    if (petRaw == 'true') {
      pet = true;
    } else if (petRaw == 'false') {
      pet = false;
    }
    return RiderIdentityState(
      riderToken: stored['rider_token'],
      identityId: stored['rider_identity_id'],
      email: stored['rider_email'],
      bookingName: stored['rider_booking_name'],
      preferredPaymentMethods: pay,
      preferredVehicleCategory: stored['rider_preferred_vehicle_category'],
      preferredPetFriendly: pet,
      isLoaded: true,
    );
  }

  /// Select columns in order until one works (older DBs may lack booking-prefs columns).
  static const _riderIdentitySelectAttempts = [
    'booking_name, preferred_payment_methods, preferred_vehicle_category, preferred_pet_friendly, app_location_permission_granted, app_notification_permission_granted, app_permissions_synced_at',
    'booking_name, preferred_payment_methods, preferred_vehicle_category, preferred_pet_friendly',
    'booking_name, preferred_payment_methods, preferred_pet_friendly',
    'booking_name',
  ];

  Future<Map<String, dynamic>?> _selectRiderIdentityRow(String identityId) async {
    Object? lastMissingColumnError;
    for (final cols in _riderIdentitySelectAttempts) {
      try {
        return await HeyCabySupabase.client
            .from('rider_identities')
            .select(cols)
            .eq('id', identityId)
            .maybeSingle();
      } catch (e) {
        final msg = e.toString();
        final missingColumn =
            msg.contains('42703') || msg.contains('does not exist');
        if (!missingColumn) rethrow;
        lastMissingColumnError = e;
      }
    }
    if (kDebugMode && lastMissingColumnError != null) {
      debugPrint('mergeServerProfile rider_identities: $lastMissingColumnError');
    }
    return null;
  }

  /// Fetches `booking_name` + default ride prefs from Supabase and refreshes secure storage.
  Future<RiderIdentityState?> _mergeServerProfile(RiderIdentityState local) async {
    final id = local.identityId;
    if (id == null || id.isEmpty) return local;

    try {
      final row = await _selectRiderIdentityRow(id);
      if (row == null) return local;

      var next = local;
      final bn = (row['booking_name'] as String?)?.trim();
      if (bn != null && bn.isNotEmpty) {
        await SecureStorage.updateRiderBookingName(bn);
        next = next.copyWith(bookingName: bn);
      }

      final pmRaw = row['preferred_payment_methods'];
      if (pmRaw is List) {
        final methods = pmRaw.map((e) => '$e').where((s) => s.isNotEmpty).toList();
        await SecureStorage.updateRiderBookingPrefs(paymentMethods: methods);
        next = next.copyWith(preferredPaymentMethods: methods);
      }

      if (row.containsKey('preferred_vehicle_category') &&
          row['preferred_vehicle_category'] != null) {
        final vc = '${row['preferred_vehicle_category']}'.trim();
        if (vc.isNotEmpty) {
          await SecureStorage.updateRiderBookingPrefs(vehicleCategory: vc);
          next = next.copyWith(preferredVehicleCategory: vc);
        }
      }

      if (row.containsKey('preferred_pet_friendly') &&
          row['preferred_pet_friendly'] != null) {
        final pf = row['preferred_pet_friendly'] as bool;
        await SecureStorage.updateRiderBookingPrefs(petFriendly: pf);
        next = next.copyWith(preferredPetFriendly: pf);
      }

      return next;
    } catch (e) {
      if (kDebugMode) debugPrint('mergeServerProfile rider_identities: $e');
      return local;
    }
  }

  Future<void> saveSession({
    required String token,
    required String identityId,
    String? email,
    String? bookingName,
  }) async {
    await SecureStorage.saveRiderIdentity(
      token: token,
      identityId: identityId,
      email: email,
      bookingName: bookingName,
    );
    final stored = await SecureStorage.getRiderIdentity();
    var next = _stateFromStored(stored);
    next = RiderIdentityState(
      riderToken: token,
      identityId: identityId,
      email: email ?? next.email,
      bookingName: bookingName ?? next.bookingName,
      preferredPaymentMethods: next.preferredPaymentMethods,
      preferredVehicleCategory: next.preferredVehicleCategory,
      preferredPetFriendly: next.preferredPetFriendly,
      isLoaded: true,
    );
    next = await _mergeServerProfile(next) ?? next;
    state = AsyncData(next);
  }

  Future<void> saveBookingName(String name) async {
    await SecureStorage.updateRiderBookingName(name);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(bookingName: name));
    }
    // Sync to Supabase rider_identities so backend stays in sync
    final identityId = current?.identityId;
    if (identityId != null && identityId.isNotEmpty) {
      try {
        await HeyCabySupabase.client
            .from('rider_identities')
            .update({'booking_name': name}).eq('id', identityId);
      } catch (e) {
        if (kDebugMode) debugPrint('Sync booking_name error: $e');
      }
    }
  }

  Future<void> saveEmail(String email) async {
    await SecureStorage.updateRiderEmail(email);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(email: email));
    }
    // Sync to Supabase rider_identities
    final identityId = current?.identityId;
    if (identityId != null && identityId.isNotEmpty) {
      try {
        await HeyCabySupabase.client
            .from('rider_identities')
            .update({'email': email}).eq('id', identityId);
      } catch (e) {
        if (kDebugMode) debugPrint('Sync email error: $e');
      }
    }
  }

  Future<void> saveGuestToken(String token) async {
    await SecureStorage.updateRiderToken(token);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(riderToken: token, isLoaded: true));
      return;
    }
    final stored = await SecureStorage.getRiderIdentity();
    state = AsyncData(_stateFromStored(stored));
  }

  Future<void> clearSession() async {
    await SecureStorage.clearRiderIdentity();
    state = const AsyncData(RiderIdentityState(isLoaded: true));
  }

  /// Persists chosen payment methods for future bookings (device + Supabase when logged in).
  Future<void> savePreferredPaymentMethods(List<String> methods) async {
    await SecureStorage.updateRiderBookingPrefs(paymentMethods: methods);
    final current = state.valueOrNull;
    final identityId = current?.identityId;
    if (current != null) {
      state = AsyncData(
        current.copyWith(preferredPaymentMethods: List<String>.from(methods)),
      );
    }
    if (identityId != null && identityId.isNotEmpty) {
      try {
        await HeyCabySupabase.client.from('rider_identities').update({
          'preferred_payment_methods': methods,
        }).eq('id', identityId);
      } catch (e) {
        if (kDebugMode) debugPrint('savePreferredPaymentMethods: $e');
      }
    }
  }

  /// Persists default vehicle category + pet flag for future bookings.
  Future<void> savePreferredVehicle(
    String category, {
    required bool petFriendly,
  }) async {
    await SecureStorage.updateRiderBookingPrefs(
      vehicleCategory: category,
      petFriendly: petFriendly,
    );
    final current = state.valueOrNull;
    final identityId = current?.identityId;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          preferredVehicleCategory: category,
          preferredPetFriendly: petFriendly,
        ),
      );
    }
    if (identityId != null && identityId.isNotEmpty) {
      try {
        await HeyCabySupabase.client.from('rider_identities').update({
          'preferred_vehicle_category': category,
          'preferred_pet_friendly': petFriendly,
        }).eq('id', identityId);
      } catch (e) {
        if (kDebugMode) debugPrint('savePreferredVehicle: $e');
      }
    }
  }
}

final riderIdentityProvider =
    AsyncNotifierProvider<RiderIdentityNotifier, RiderIdentityState>(
  RiderIdentityNotifier.new,
);
