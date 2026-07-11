import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heycaby_api/src/app_notifications_service.dart';
import 'package:heycaby_api/src/rider_session_service.dart';
import 'package:heycaby_api/src/supabase_client.dart';

class RiderApi {
  static const _notifications = AppNotificationsService();

  const RiderApi();

  Future<List<RiderNotificationItem>> getNotifications({
    required String riderIdentityId,
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final supabaseRows = await _notifications.listOrNull(
      userType: 'rider',
      unreadOnly: unreadOnly,
      limit: limit,
      riderIdentityId: riderIdentityId,
    );
    return (supabaseRows ?? const [])
        .map((e) => RiderNotificationItem.fromJson(e))
        .toList();
  }

  Future<void> markNotificationRead({
    required String riderIdentityId,
    required String notificationId,
  }) async {
    await _notifications.markRead(notificationId);
  }

  Future<void> markAllNotificationsRead(
      {required String riderIdentityId}) async {
    await _notifications.markAllRead(
      userType: 'rider',
      riderIdentityId: riderIdentityId,
    );
  }

  Future<void> clearReadNotifications({required String riderIdentityId}) async {
    await _notifications.clearRead(
      userType: 'rider',
      riderIdentityId: riderIdentityId,
    );
  }

  /// Fetches a completed-ride receipt payload for rider view (Supabase RPC).
  Future<Map<String, dynamic>?> fetchRideReceipt({
    required String rideRequestId,
    String? riderToken,
  }) async {
    try {
      const sessions = RiderSessionService();
      final token = await sessions.fetchRideRiderToken(
        rideRequestId,
        hintToken: riderToken,
      );
      final params = <String, dynamic>{
        'p_ride_request_id': rideRequestId,
      };
      if (token != null && token.isNotEmpty) {
        params['p_rider_token'] = token;
      }
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_receipt_for_ride',
        params: params,
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Rider confirms they verified the assigned plate for an active ride.
  Future<bool> attestPlateForRide({
    required String rideRequestId,
    required String expectedPlate,
    String outcome = 'confirmed',
  }) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_attest_plate',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_expected_plate': expectedPlate,
          'p_outcome': outcome,
        },
      );
      if (raw is! Map) return false;
      return Map<String, dynamic>.from(raw)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Whether the rider already attested the plate for this ride.
  Future<bool> isPlateAttestedForRide(String rideRequestId) async {
    try {
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_plate_attestation_for_ride',
        params: {'p_ride_request_id': rideRequestId},
      );
      if (raw is! Map) return false;
      final map = Map<String, dynamic>.from(raw);
      return map['ok'] == true && map['verified'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Accept marketplace bid — Supabase-backed in app.
  Future<void> acceptBid({
    required String rideRequestId,
    required String bidId,
  }) async {
    throw UnsupportedError(
      'Use Supabase ride_requests update (acceptMarketplaceOffer).',
    );
  }

  /// Fetch Taxi Terug candidate drivers heading toward the rider's destination.
  /// Returns privacy-safe driver cards (first name, vehicle, ETA, fare range, match score).
  Future<Map<String, dynamic>?> fetchTaxiTerugCandidates({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    int limit = 10,
    int? maxWaitMinutes,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_destination_lat': destinationLat,
        'p_destination_lng': destinationLng,
        'p_limit': limit,
      };
      if (maxWaitMinutes != null) {
        params['p_max_wait_minutes'] = maxWaitMinutes;
      }
      final raw = await HeyCabySupabase.client.rpc(
        'fn_rider_taxi_terug_candidates',
        params: params,
      );
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }
}

final riderApiProvider = Provider<RiderApi>((_) => const RiderApi());

class RiderNotificationItem {
  const RiderNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.priority,
    this.readAt,
    this.createdAt,
    this.data,
  });

  final String id;
  final String title;
  final String body;
  final String? category;
  final String? priority;
  final DateTime? readAt;
  final DateTime? createdAt;
  final Map<String, dynamic>? data;

  bool get isUnread => readAt == null;

  static DateTime? _parseDate(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  factory RiderNotificationItem.fromJson(Map<String, dynamic> j) {
    return RiderNotificationItem(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      category: j['category'] as String?,
      priority: j['priority'] as String?,
      readAt: _parseDate(j['read_at']),
      createdAt: _parseDate(j['created_at']),
      data:
          j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : null,
    );
  }
}
