import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'rider_plate_verifications_pending_v1';

/// Rider-confirmed plate check during an active ride. Stored locally until
/// synced to Supabase in a later pass.
class RiderPlateVerificationRecord {
  const RiderPlateVerificationRecord({
    required this.rideRequestId,
    required this.expectedPlate,
    required this.rideStatus,
    required this.verifiedAt,
    this.driverId,
  });

  final String rideRequestId;
  final String? driverId;
  final String expectedPlate;
  final String rideStatus;
  final DateTime verifiedAt;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'ride_request_id': rideRequestId,
        'driver_id': driverId,
        'expected_plate': expectedPlate,
        'ride_status': rideStatus,
        'verified_at': verifiedAt.toUtc().toIso8601String(),
      };

  factory RiderPlateVerificationRecord.fromJson(Map<String, dynamic> json) {
    return RiderPlateVerificationRecord(
      rideRequestId: json['ride_request_id'] as String,
      driverId: json['driver_id'] as String?,
      expectedPlate: (json['expected_plate'] as String?) ?? '',
      rideStatus: (json['ride_status'] as String?) ?? '',
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class RiderPlateVerificationStorage {
  RiderPlateVerificationStorage._();

  static Future<List<RiderPlateVerificationRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RiderPlateVerificationRecord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isVerifiedForRide(String rideRequestId) async {
    final all = await loadAll();
    return all.any((r) => r.rideRequestId == rideRequestId);
  }

  static Future<void> save(RiderPlateVerificationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll()
      ..removeWhere((r) => r.rideRequestId == record.rideRequestId)
      ..add(record);
    await prefs.setString(
      _prefsKey,
      jsonEncode(all.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> removeForRide(String rideRequestId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll()
      ..removeWhere((r) => r.rideRequestId == rideRequestId);
    if (all.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(
      _prefsKey,
      jsonEncode(all.map((r) => r.toJson()).toList()),
    );
  }

  /// For a future Supabase sync job — returns pending rows and clears local queue.
  static Future<List<RiderPlateVerificationRecord>> drainPending() async {
    final all = await loadAll();
    if (all.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    return all;
  }
}
