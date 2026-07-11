import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> saveRiderIdentity({
    required String token,
    required String identityId,
    String? email,
    String? bookingName,
  }) async {
    await Future.wait([
      _storage.write(key: 'rider_token', value: token),
      _storage.write(key: 'rider_identity_id', value: identityId),
      if (email != null) _storage.write(key: 'rider_email', value: email),
      if (bookingName != null)
        _storage.write(key: 'rider_booking_name', value: bookingName),
    ]);
  }

  static Future<Map<String, String?>> getRiderIdentity() async {
    final results = await Future.wait([
      _storage.read(key: 'rider_token'),
      _storage.read(key: 'rider_identity_id'),
      _storage.read(key: 'rider_email'),
      _storage.read(key: 'rider_booking_name'),
      _storage.read(key: 'rider_preferred_payment_json'),
      _storage.read(key: 'rider_preferred_vehicle_category'),
      _storage.read(key: 'rider_preferred_pet_friendly'),
    ]);
    return {
      'rider_token': results[0],
      'rider_identity_id': results[1],
      'rider_email': results[2],
      'rider_booking_name': results[3],
      'rider_preferred_payment_json': results[4],
      'rider_preferred_vehicle_category': results[5],
      'rider_preferred_pet_friendly': results[6],
    };
  }

  static Future<void> updateRiderBookingName(String name) async {
    await _storage.write(key: 'rider_booking_name', value: name);
  }

  static Future<void> updateRiderEmail(String email) async {
    await _storage.write(key: 'rider_email', value: email);
  }

  static Future<void> updateRiderToken(String token) async {
    await _storage.write(key: 'rider_token', value: token);
  }

  static Future<void> updateRiderIdentityId(String identityId) async {
    await _storage.write(key: 'rider_identity_id', value: identityId);
  }

  /// Persists default payment / vehicle choices for the booking flow (device cache).
  static Future<void> updateRiderBookingPrefs({
    List<String>? paymentMethods,
    String? vehicleCategory,
    bool? petFriendly,
  }) async {
    final futures = <Future<void>>[];
    if (paymentMethods != null) {
      futures.add(
        _storage.write(
          key: 'rider_preferred_payment_json',
          value: jsonEncode(paymentMethods),
        ),
      );
    }
    if (vehicleCategory != null) {
      futures.add(
        _storage.write(
          key: 'rider_preferred_vehicle_category',
          value: vehicleCategory,
        ),
      );
    }
    if (petFriendly != null) {
      futures.add(
        _storage.write(
          key: 'rider_preferred_pet_friendly',
          value: petFriendly ? 'true' : 'false',
        ),
      );
    }
    await Future.wait(futures);
  }

  static Future<void> clearRiderIdentity() async {
    await Future.wait([
      _storage.delete(key: 'rider_token'),
      _storage.delete(key: 'rider_identity_id'),
      _storage.delete(key: 'rider_email'),
      _storage.delete(key: 'rider_booking_name'),
      _storage.delete(key: 'rider_preferred_payment_json'),
      _storage.delete(key: 'rider_preferred_vehicle_category'),
      _storage.delete(key: 'rider_preferred_pet_friendly'),
    ]);
  }
}
